@testable import Folio
import Foundation
import XCTest

final class AskSavedNoteFormatterTests: XCTestCase {

    // MARK: - formatTitle

    func testFormatTitleFromQuestion() {
        let title = AskSavedNoteFormatter.formatTitle(from: "What is the evidence?")
        XCTAssertEqual(title, "What is the evidence?")
    }

    func testFormatTitleTrimsWhitespace() {
        let title = AskSavedNoteFormatter.formatTitle(from: "  spaces  ")
        XCTAssertEqual(title, "spaces")
    }

    func testFormatTitleClampsToMaxLength() {
        let long = String(repeating: "a", count: 200)
        let title = AskSavedNoteFormatter.formatTitle(from: long)
        XCTAssertEqual(title.count, AskSavedNoteFormatter.titleMaxLength)
    }

    func testFormatTitleFallsBackToDefaultForEmpty() {
        let title = AskSavedNoteFormatter.formatTitle(from: "   ")
        XCTAssertEqual(title, AskSavedNoteFormatter.defaultTitle)
    }

    // MARK: - formatContent

    func testFormatContentAnswerOnly() {
        let result = AskSavedNoteFormatter.formatContent(
            answer: "The evidence shows X", limitation: nil, citations: [])
        XCTAssertEqual(result, "The evidence shows X")
    }

    func testFormatContentWithLimitation() {
        let result = AskSavedNoteFormatter.formatContent(
            answer: "Answer", limitation: "May be incomplete", citations: [])
        XCTAssertTrue(result.contains("Answer"))
        XCTAssertTrue(result.contains("Limitation: May be incomplete"))
    }

    func testFormatContentWithEmptyLimitationOmitted() {
        let result = AskSavedNoteFormatter.formatContent(
            answer: "Answer", limitation: "   ", citations: [])
        XCTAssertFalse(result.contains("Limitation"))
    }

    func testFormatContentWithCitations() {
        let citation = AskCitation(
            index: 0, sourceID: "s1", sourceTitle: "Source A",
            sourceKind: .file, locationLabel: "p.5", evidenceText: "quote here")
        let result = AskSavedNoteFormatter.formatContent(
            answer: "Answer", limitation: nil, citations: [citation])
        XCTAssertTrue(result.contains("Evidence"))
        XCTAssertTrue(result.contains("[0] Source A — p.5"))
        XCTAssertTrue(result.contains("quote here"))
    }

    func testFormatContentWithMultipleCitationsSortedByIndex() {
        let c1 = AskCitation(
            index: 2, sourceID: "s2", sourceTitle: "Second",
            sourceKind: nil, locationLabel: "", evidenceText: "b")
        let c2 = AskCitation(
            index: 0, sourceID: "s1", sourceTitle: "First",
            sourceKind: nil, locationLabel: "", evidenceText: "a")
        let result = AskSavedNoteFormatter.formatContent(
            answer: "Answer", limitation: nil, citations: [c1, c2])
        let firstIndex = result.range(of: "[0]")!.lowerBound
        let secondIndex = result.range(of: "[2]")!.lowerBound
        XCTAssertLessThan(firstIndex, secondIndex)
    }

    func testFormatContentTruncatesToMaxLength() {
        let longAnswer = String(repeating: "x", count: NoteLimits.maximumContentLength + 500)
        let result = AskSavedNoteFormatter.formatContent(
            answer: longAnswer, limitation: nil, citations: [])
        XCTAssertEqual(result.count, NoteLimits.maximumContentLength)
    }

    func testFormatContentWithEmptyCitationsOmitsEvidence() {
        let result = AskSavedNoteFormatter.formatContent(
            answer: "Answer", limitation: nil, citations: [])
        XCTAssertFalse(result.contains("Evidence"))
    }

    func testFormatContentCitationWithoutLocation() {
        let citation = AskCitation(
            index: 0, sourceID: "s1", sourceTitle: "Source",
            sourceKind: nil, locationLabel: "", evidenceText: "text")
        let result = AskSavedNoteFormatter.formatContent(
            answer: "Answer", limitation: nil, citations: [citation])
        // Empty locationLabel → no " — " separator
        XCTAssertTrue(result.contains("[0] Source\n"))
    }
}
