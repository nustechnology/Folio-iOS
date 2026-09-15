import Combine
import XCTest
@testable import Folio

@MainActor
final class NoteRichTextEditingModelTests: XCTestCase {
    func testInitialSerializationDifferenceDoesNotCountAsAnEdit() {
        let model = NoteRichTextEditingModel(
            attributedText: FolioRichTextEditor.attributedTextFromHTML("Answer\nLimitation: details"),
            publishingHTML: { _ in }
        )

        XCTAssertNotEqual(model.serializedContent, "Answer\nLimitation: details")
        XCTAssertFalse(model.hasUnsavedChanges)
        XCTAssertEqual(model.contentForSave(fallback: "Answer\nLimitation: details"), "Answer\nLimitation: details")

        model.textChanged(NSAttributedString(string: "Edited answer"))

        XCTAssertTrue(model.hasUnsavedChanges)
        XCTAssertEqual(model.contentForSave(fallback: "Answer\nLimitation: details"), model.serializedContent)
    }

    func testEquivalentSerializedContentDoesNotCountAsAnEditWhenAttributesDiffer() {
        let initialText = NSAttributedString(string: "Answer")
        let initialHTML = FolioRichTextEditor.htmlFromAttributedText(initialText)
        let normalizedText = FolioRichTextEditor.attributedTextFromHTML(initialHTML)
        XCTAssertNotEqual(initialText, normalizedText)
        XCTAssertEqual(FolioRichTextEditor.htmlFromAttributedText(normalizedText), initialHTML)

        let model = NoteRichTextEditingModel(
            attributedText: initialText,
            publishingHTML: { _ in }
        )

        model.textChanged(normalizedText)

        XCTAssertFalse(model.hasUnsavedChanges)
        XCTAssertEqual(model.contentForSave(fallback: "original content"), "original content")
    }

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

    func testTextChangeUpdatesCachedContentRepresentations() {
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: "Before"),
            publishingHTML: { _ in }
        )

        model.textChanged(NSAttributedString(string: "After"))

        XCTAssertEqual(model.serializedContent, FolioRichTextEditor.htmlFromAttributedText(model.attributedText))
        XCTAssertEqual(model.plainText, "After")
    }

    func testTextChangePublishesHTMLWhenBindingUpdatedBeforeCallback() {
        var publishedHTML: String?
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: ""),
            publishingHTML: { publishedHTML = $0 }
        )
        let editedText = NSAttributedString(string: "Content")

        model.attributedText = editedText
        model.textChanged(editedText)

        XCTAssertEqual(publishedHTML, FolioRichTextEditor.htmlFromAttributedText(editedText))
    }

    func testTextChangeDoesNotRepublishIdenticalBindingValue() {
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: ""),
            publishingHTML: { _ in }
        )
        let editedText = NSAttributedString(string: "Content")
        var bindingUpdates = 0
        let subscription = model.$attributedText
            .sink { _ in bindingUpdates += 1 }

        model.attributedText = editedText
        model.textChanged(editedText)

        XCTAssertEqual(bindingUpdates, 2)
        withExtendedLifetime(subscription) {}
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

    func testApplyingBlockquoteToEmptyEditorActivatesQuoteToolbar() {
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: ""),
            publishingHTML: { _ in }
        )

        model.applyBlockquote()

        XCTAssertEqual(model.attributedText.string, FolioRichTextFormat.blockquoteMarker)
        XCTAssertEqual(model.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertTrue(model.toolbarActiveFormats.isBlockquote)
    }
}
