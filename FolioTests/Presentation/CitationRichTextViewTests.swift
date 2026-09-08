import XCTest
@testable import Folio

final class CitationRichTextViewTests: XCTestCase {
    func testPlainTextContentIsRenderedWhenItHasNoHTMLBlockTag() {
        let attributed = CitationRichTextView.inlineAttributedString(
            content: "The evidence indicates that 0 sources are shown.",
            citationCount: 0
        )

        XCTAssertEqual(attributed.string, "The evidence indicates that 0 sources are shown.")
    }

    func testValidCitationMarkerIsRenderedAsCitationLink() {
        let attributed = CitationRichTextView.inlineAttributedString(
            content: "<p>Evidence [1] supports the claim.</p>",
            citationCount: 1
        )
        let markerRange = (attributed.string as NSString).range(of: "[1]")

        XCTAssertEqual(
            attributed.attribute(.link, at: markerRange.location, effectiveRange: nil) as? URL,
            URL(string: "folio-citation://1")
        )
    }

    func testOutOfRangeCitationMarkerIsNotRenderedAsCitationLink() {
        let attributed = CitationRichTextView.inlineAttributedString(
            content: "<p>Evidence [2] is unavailable.</p>",
            citationCount: 1
        )
        let markerRange = (attributed.string as NSString).range(of: "[2]")

        XCTAssertNil(attributed.attribute(.link, at: markerRange.location, effectiveRange: nil))
    }

    func testCitationOpenActionUsesCitationSourceID() {
        let citation = NoteCitation(
            id: "citation-1",
            sourceId: "source-1",
            sourceTitle: "Web source",
            sourceType: "Web",
            sourceAuthor: "Publisher",
            passageId: "passage-1",
            snippet: "Evidence",
            locationLabel: nil,
            pageReference: nil,
            sectionReference: nil
        )
        let note = Note(
            id: "note-1",
            researchSpaceId: "space-1",
            title: "Note",
            originType: .savedAssistantAnswer,
            content: "[1]",
            createdAt: .now,
            updatedAt: .now,
            citationCount: 1,
            citations: [citation]
        )

        XCTAssertEqual(citation.sourceId, "source-1")
        XCTAssertEqual(note.citations.first?.sourceId, citation.sourceId)
    }
}
