import Foundation

final class SourceStatusSSEClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect(endpoint: SourceStatusEndpoint) -> AsyncThrowingStream<SourceStatusEvent, Error> {
        AsyncThrowingStream { continuation in
            let streamTask = Task {
                do {
                    guard endpoint.url.scheme == "https" else {
                        Logger.error("SSE refused: non-HTTPS URL \(endpoint.url.absoluteString)")
                        continuation.finish(throwing: NetworkError.insecureURL)
                        return
                    }

                    Logger.debug("SSE → connecting to \(endpoint.url.absoluteString)")

                    let (bytes, response) = try await self.session.bytes(for: endpoint.urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        Logger.error("SSE ← invalid response: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                        continuation.finish(throwing: NetworkError.invalidResponse)
                        return
                    }

                    Logger.debug("SSE ← connected (status: \(httpResponse.statusCode))")

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else {
                            Logger.debug("SSE stream cancelled")
                            continuation.finish()
                            return
                        }

                        let trimmed = line.trimmingCharacters(in: .whitespaces)

                        guard trimmed.hasPrefix("data:"), trimmed.count > 5 else { continue }

                        let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard !jsonString.isEmpty, let data = jsonString.data(using: .utf8) else { continue }

                        do {
                            let event = try JSONDecoder().decode(SourceStatusEvent.self, from: data)
                            Logger.debug("SSE event: sourceId=\(event.sourceId) state=\(event.state) progress=\(event.progress)")
                            continuation.yield(event)
                        } catch {
                            Logger.debug("SSE skip malformed event: \(error)")
                        }
                    }

                    Logger.debug("SSE stream ended")
                    continuation.finish()
                } catch {
                    if !(error is CancellationError) {
                        Logger.error("SSE error: \(error)")
                        continuation.finish(throwing: error)
                    } else {
                        Logger.debug("SSE cancelled")
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }
}
