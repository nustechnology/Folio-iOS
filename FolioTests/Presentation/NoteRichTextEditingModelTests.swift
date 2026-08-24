import XCTest
@testable import Folio

@MainActor
final class NoteRichTextEditingModelTests: XCTestCase {
    func testTextChangePublishesHTML() {
        var publishedHTML: String?
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: "Before"),
            publishingHTML: { publishedHTML = $0 }
        )

        model.textChanged(NSAttributedString(string: "After"))

        XCTAssertEqual(model.attributedText.string, "After")
        XCTAssertEqual(publishedHTML, FolioRichTextEditor.htmlFromAttributedText(model.attributedText))
    }

    func testLinkPromptRequiresSelectionAndValidatesURL() {
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: "Text"),
            publishingHTML: { _ in }
        )

        XCTAssertFalse(model.presentLinkPrompt())

        model.selectedRange = NSRange(location: 0, length: 4)
        XCTAssertTrue(model.presentLinkPrompt())

        model.linkURL = "not a supported URL"

        XCTAssertFalse(model.applyLink())
        XCTAssertEqual(model.linkError, String(localized: "Invalid URL"))
    }
}
