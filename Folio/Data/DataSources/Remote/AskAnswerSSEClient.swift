import Foundation

final class AskAnswerSSEClient {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            // No per-request data timeout — the server may take arbitrarily long
            // to begin generating. User cancellation via stopStreaming() is the
            // stall detector.
            configuration.timeoutIntervalForRequest = .greatestFiniteMagnitude
            configuration.timeoutIntervalForResource = .greatestFiniteMagnitude
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }
    }

    func connect(endpoint: AskStreamAnswerEndpoint) -> AsyncThrowingStream<AskAnswerStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let streamTask = Task {
                do {
                    guard endpoint.url.scheme == "https" else {
                        Logger.error("Ask SSE refused: non-HTTPS URL \(endpoint.url.absoluteString)")
                        continuation.finish(throwing: NetworkError.insecureURL)
                        return
                    }

                    if let bodyString = String(data: endpoint.body, encoding: .utf8) {
                        Logger.debug("Ask SSE → connecting to \(endpoint.url.absoluteString) with body: \(bodyString)")
                    } else {
                        Logger.debug("Ask SSE → connecting to \(endpoint.url.absoluteString)")
                    }

                    let (bytes, response) = try await self.session.bytes(for: endpoint.urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        Logger.error("Ask SSE ← invalid response (not HTTP)")
                        continuation.finish(throwing: NetworkError.invalidResponse)
                        return
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        let maximumErrorBodySize = 64 * 1024
                        var errorBody = Data()
                        for try await byte in bytes {
                            guard errorBody.count < maximumErrorBodySize else { break }
                            errorBody.append(byte)
                        }
                        let bodyString = String(data: errorBody, encoding: .utf8) ?? ""
                        Logger.error("Ask SSE ← HTTP \(httpResponse.statusCode): \(bodyString)")
                        continuation.finish(throwing: NetworkError.httpError(statusCode: httpResponse.statusCode, data: errorBody))
                        return
                    }

                    Logger.debug("Ask SSE ← connected (status: \(httpResponse.statusCode))")

                    let decoder = JSONDecoder()
                    var currentEventName: String?
                    var dataLines: [String] = []

                    let flushPendingEvent = { () -> AskAnswerStreamEvent? in
                        guard let eventName = currentEventName, !dataLines.isEmpty else {
                            currentEventName = nil
                            dataLines = []
                            return nil
                        }
                        let jsonString = dataLines.joined(separator: "\n")
                        currentEventName = nil
                        dataLines = []
                        guard let data = jsonString.data(using: .utf8) else { return nil }
                        do {
                            if let event = try Self.decodeEvent(name: eventName, data: data, decoder: decoder) {
                                return event
                            } else {
                                Logger.debug("Ask SSE skip unknown event: \(eventName)")
                                return nil
                            }
                        } catch {
                            Logger.debug("Ask SSE skip malformed event (\(eventName)): \(error)")
                            return nil
                        }
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else {
                            Logger.debug("Ask SSE stream cancelled")
                            continuation.finish()
                            return
                        }

                        #if DEBUG
                        Logger.debug("Ask SSE line ← \(line)")
                        #endif

                        let trimmed = line.trimmingCharacters(in: .whitespaces)

                        if trimmed.isEmpty {
                            if let event = flushPendingEvent() {
                                continuation.yield(event)
                            }
                            continue
                        }

                        if trimmed.hasPrefix("event:") {
                            if let event = flushPendingEvent() {
                                continuation.yield(event)
                            }
                            currentEventName = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            continue
                        }

                        if trimmed.hasPrefix("data:") {
                            let value = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            dataLines.append(value)
                            continue
                        }

                        // Ignore id:, retry:, comments, and any other fields
                    }

                    if let event = flushPendingEvent() {
                        continuation.yield(event)
                    }

                    Logger.debug("Ask SSE stream ended")
                    continuation.finish()
                } catch {
                    if !(error is CancellationError) {
                        Logger.error("Ask SSE error: \(error)")
                        continuation.finish(throwing: error)
                    } else {
                        Logger.debug("Ask SSE cancelled")
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }

    /// Parses an async sequence of SSE text lines into stream events.
    /// Extracted for direct testing without URLSession.
    static func parseLines<L: AsyncSequence>(
        _ lines: L
    ) async throws -> [AskAnswerStreamEvent] where L.Element == String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var currentEventName: String?
        var dataLines: [String] = []
        var events: [AskAnswerStreamEvent] = []

        let flushPendingEvent = { () -> AskAnswerStreamEvent? in
            guard let eventName = currentEventName, !dataLines.isEmpty else {
                currentEventName = nil
                dataLines = []
                return nil
            }
            let jsonString = dataLines.joined(separator: "\n")
            currentEventName = nil
            dataLines = []
            guard let data = jsonString.data(using: .utf8) else { return nil }
            return try? decodeEvent(name: eventName, data: data, decoder: decoder)
        }

        for try await line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if let event = flushPendingEvent() {
                    events.append(event)
                }
                continue
            }

            if trimmed.hasPrefix("event:") {
                if let event = flushPendingEvent() {
                    events.append(event)
                }
                currentEventName = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if trimmed.hasPrefix("data:") {
                let value = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                dataLines.append(value)
                continue
            }
        }

        if let event = flushPendingEvent() {
            events.append(event)
        }

        return events
    }

    static func decodeEvent(
        name: String, data: Data, decoder: JSONDecoder
    ) throws -> AskAnswerStreamEvent? {
        switch name {
        case "start":
            let dto = try decoder.decode(AskStreamStartDTO.self, from: data)
            return .start(conversationId: dto.conversationId, messageId: dto.messageId)
        case "token":
            let dto = try decoder.decode(AskStreamTokenDTO.self, from: data)
            return .token(dto.text)
        case "citations":
            let dto = try decoder.decode(AskStreamCitationsDTO.self, from: data)
            return .citations(dto.citations.enumerated().map { $1.toDomain(position: $0) })
        case "done":
            let dto = try decoder.decode(AskStreamDoneDTO.self, from: data)
            return .done(
                messageId: dto.messageId,
                content: dto.content,
                citations: dto.citations.enumerated().map { $1.toDomain(position: $0) },
                limitation: dto.limitation,
                stopped: dto.stopped
            )
        case "error":
            let dto = try decoder.decode(AskStreamErrorDTO.self, from: data)
            return .error(dto.message)
        default:
            return nil
        }
    }
}
