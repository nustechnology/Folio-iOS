@testable import Folio
import Foundation
import XCTest

// MARK: - decodeEvent (static) table tests

final class AskAnswerSSEClientDecodeEventTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func testDecodeStartEvent() throws {
        let data = "{\"conversation_id\":\"conv-1\",\"message_id\":\"m1\"}".data(using: .utf8)!
        let event = try AskAnswerSSEClient.decodeEvent(name: "start", data: data, decoder: decoder)
        if case .start(let cid, let mid) = event {
            XCTAssertEqual(cid, "conv-1")
            XCTAssertEqual(mid, "m1")
        } else {
            XCTFail("Expected .start")
        }
    }

    func testDecodeTokenEvent() throws {
        let data = "{\"text\":\"Hello\"}".data(using: .utf8)!
        let event = try AskAnswerSSEClient.decodeEvent(name: "token", data: data, decoder: decoder)
        if case .token(let text) = event {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected .token")
        }
    }

    func testDecodeCitationsEvent() throws {
        let json = "{\"citations\":[{\"index\":0,\"source_id\":\"s1\",\"source_title\":\"Title\",\"source_kind\":\"file\",\"location_label\":\"p.1\",\"evidence_text\":\"quote\"}]}"
        let data = json.data(using: .utf8)!
        let event = try AskAnswerSSEClient.decodeEvent(name: "citations", data: data, decoder: decoder)
        if case .citations(let citations) = event {
            XCTAssertEqual(citations.count, 1)
            XCTAssertEqual(citations[0].sourceId, "s1")
            XCTAssertEqual(citations[0].evidenceText, "quote")
        } else {
            XCTFail("Expected .citations")
        }
    }

    func testDecodeDoneEvent() throws {
        let json = "{\"message_id\":\"m1\",\"content\":\"Answer\",\"citations\":[],\"limitation\":null,\"stopped\":false}"
        let data = json.data(using: .utf8)!
        let event = try AskAnswerSSEClient.decodeEvent(name: "done", data: data, decoder: decoder)
        if case .done(let mid, let content, let cites, let lim, let stopped) = event {
            XCTAssertEqual(mid, "m1")
            XCTAssertEqual(content, "Answer")
            XCTAssertTrue(cites.isEmpty)
            XCTAssertNil(lim)
            XCTAssertFalse(stopped)
        } else {
            XCTFail("Expected .done")
        }
    }

    func testDecodeDoneWithLimitation() throws {
        let json = "{\"message_id\":\"m1\",\"content\":\"A\",\"citations\":[],\"limitation\":\"May be incomplete\",\"stopped\":false}"
        let data = json.data(using: .utf8)!
        let event = try AskAnswerSSEClient.decodeEvent(name: "done", data: data, decoder: decoder)
        if case .done(_, _, _, let lim, _) = event {
            XCTAssertEqual(lim, "May be incomplete")
        } else {
            XCTFail("Expected .done")
        }
    }

    func testDecodeErrorEvent() throws {
        let data = "{\"message\":\"rate limited\"}".data(using: .utf8)!
        let event = try AskAnswerSSEClient.decodeEvent(name: "error", data: data, decoder: decoder)
        if case .error(let msg) = event {
            XCTAssertEqual(msg, "rate limited")
        } else {
            XCTFail("Expected .error")
        }
    }

    func testDecodeUnknownEventReturnsNil() throws {
        let data = "{\"foo\":\"bar\"}".data(using: .utf8)!
        let event = try AskAnswerSSEClient.decodeEvent(name: "ping", data: data, decoder: decoder)
        XCTAssertNil(event)
    }

    func testDecodeMalformedJSONThrows() {
        let data = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try AskAnswerSSEClient.decodeEvent(name: "token", data: data, decoder: decoder))
    }
}

// MARK: - Line parser tests

final class AskAnswerSSEClientLineParserTests: XCTestCase {

    func testSingleLineStartEvent() async throws {
        let events = try await parse(["event: start", "data: {\"conversation_id\":\"c1\",\"message_id\":\"m1\"}", ""])
        XCTAssertEqual(events.count, 1)
        if case .start(let cid, let mid) = events.first {
            XCTAssertEqual(cid, "c1")
            XCTAssertEqual(mid, "m1")
        } else {
            XCTFail("Expected .start")
        }
    }

    func testSingleLineTokenEvent() async throws {
        let events = try await parse(["event: token", "data: {\"text\":\"Hi\"}", ""])
        XCTAssertEqual(events.count, 1)
        if case .token(let text) = events.first {
            XCTAssertEqual(text, "Hi")
        } else {
            XCTFail("Expected .token")
        }
    }

    func testMultiLineDataSingleJSONSplit() async throws {
        // Server splits JSON across data: lines at a valid token boundary
        let lines = [
            "event: done",
            "data: {\"message_id\":\"m1\",\"content\":\"Hello World\",\"citations\":[],",
            "data: \"limitation\":null,\"stopped\":false}",
            "",
        ]
        let events = try await parse(lines)
        XCTAssertEqual(events.count, 1)
        if case .done(_, let content, _, _, _) = events.first {
            XCTAssertEqual(content, "Hello World")
        } else {
            XCTFail("Expected .done")
        }
    }

    func testMultiLineDataTwoSeparateJSONObjects() async throws {
        let events = try await parse([
            "event: token", "data: {\"text\":\"A\"}", "data: {\"text\":\"B\"}", "",
        ])
        XCTAssertTrue(events.isEmpty)
    }

    func testDataBeforeEventSkipped() async throws {
        let events = try await parse(["data: {\"text\":\"orphan\"}", ""])
        XCTAssertTrue(events.isEmpty)
    }

    func testDataThenEventDecodesCorrectly() async throws {
        let events = try await parse(["data: {\"text\":\"Hi\"}", "event: token", ""])
        XCTAssertEqual(events.count, 1)
        if case .token(let text) = events.first {
            XCTAssertEqual(text, "Hi")
        } else {
            XCTFail("Expected .token")
        }
    }

    func testEventNameResetsAcrossBlocks() async throws {
        let events = try await parse([
            "event: token", "data: {\"text\":\"A\"}", "",
            "event: token", "data: {\"text\":\"B\"}", "",
        ])
        XCTAssertEqual(events.count, 2)
    }

    func testCommentLinesIgnored() async throws {
        let events = try await parse([": keepalive", "event: token", "data: {\"text\":\"X\"}", ""])
        XCTAssertEqual(events.count, 1)
        if case .token(let text) = events.first {
            XCTAssertEqual(text, "X")
        } else {
            XCTFail("Expected .token")
        }
    }

    func testUnknownEventNameSkipped() async throws {
        let events = try await parse(["event: ping", "data: {}", ""])
        XCTAssertTrue(events.isEmpty)
    }

    func testMalformedJSONSkipped() async throws {
        let events = try await parse(["event: token", "data: not-json", ""])
        XCTAssertTrue(events.isEmpty)
    }

    func testEmptyDataLineIgnored() async throws {
        let events = try await parse(["event: token", "data: ", ""])
        XCTAssertTrue(events.isEmpty)
    }

    func testMultipleEventsInSequence() async throws {
        let events = try await parse([
            "event: start",
            "data: {\"conversation_id\":\"c1\",\"message_id\":\"m1\"}",
            "",
            "event: token",
            "data: {\"text\":\"Hello\"}",
            "",
            "event: token",
            "data: {\"text\":\" world\"}",
            "",
            "event: done",
            "data: {\"message_id\":\"m1\",\"content\":\"Hello world\",\"citations\":[],\"limitation\":null,\"stopped\":false}",
            "",
        ])
        XCTAssertEqual(events.count, 4)
        guard events.count == 4 else { return }

        if case .start(let cid, _) = events[0] { XCTAssertEqual(cid, "c1") } else { XCTFail("Expected .start") }
        if case .token(let t) = events[1] { XCTAssertEqual(t, "Hello") } else { XCTFail("Expected .token") }
        if case .token(let t) = events[2] { XCTAssertEqual(t, " world") } else { XCTFail("Expected .token") }
        if case .done(_, let content, _, _, _) = events[3] { XCTAssertEqual(content, "Hello world") } else { XCTFail("Expected .done") }
    }

    func testNonHTTPSRejected() async {
        let endpoint = try! AskStreamAnswerEndpoint(
            baseURL: URL(string: "http://example.com")!,
            spaceId: "s1", question: "test", scope: "space",
            sourceId: nil, conversationId: nil, accessToken: nil)
        let client = AskAnswerSSEClient()
        let stream = client.connect(endpoint: endpoint)
        var threw = false
        do {
            for try await _ in stream { }
        } catch {
            threw = true
            XCTAssertTrue(error is NetworkError)
        }
        XCTAssertTrue(threw)
    }

    func testAskQuestionRequestDTOEncodingExcludesNilSourceId() throws {
        let request = AskQuestionRequestDTO(question: "What problems?", scope: "space", sourceId: nil, conversationId: nil)
        let data = try JSONEncoder().encode(request)
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertFalse(jsonString.contains("sourceId"))
    }

    // MARK: - Helper

    private func parse(_ lines: [String]) async throws -> [AskAnswerStreamEvent] {
        let stream = AsyncStream<String> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        return try await AskAnswerSSEClient.parseLines(stream)
    }
}
