@testable import Folio
import SwiftUI
import UIKit
import XCTest

final class FolioRichTextEditorRoundTripTests: XCTestCase {
    func testInlineToolbarLayoutDoesNotChangeRichTextSerialization() {
        let text = NSMutableAttributedString(string: "Note")
        text.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 16), range: NSRange(location: 0, length: text.length))

        XCTAssertEqual(
            FolioRichTextEditor.htmlFromAttributedText(text),
            "<p><em>Note</em></p>"
        )
    }

    func testFormattingDoesNotPublishWhenAttributedContentIsUnchanged() {
        let empty = FolioRichTextEditor.makeDefaultAttributedText()

        XCTAssertFalse(FolioRichTextEditor.shouldPublishContentChange(from: empty, to: empty))
        XCTAssertTrue(
            FolioRichTextEditor.shouldPublishContentChange(
                from: empty,
                to: NSAttributedString(string: "Note")
            )
        )
    }

    func testCoordinatorIgnoresSelectionChangesWhileUIViewIsSynchronizing() {
        var selectedRange = NSRange(location: 0, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let editor = FolioRichTextEditor(
            attributedText: .constant(NSAttributedString(string: "text")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        coordinator.isSynchronizingUIView = true

        let textView = UITextView()
        textView.selectedRange = NSRange(location: 2, length: 0)
        coordinator.textViewDidChangeSelection(textView)

        XCTAssertEqual(selectedRange, NSRange(location: 0, length: 0))
        XCTAssertTrue(typingAttributes.isEmpty)
    }

    func testCoordinatorClearsLinkTypingAttributeAfterSpace() {
        var selectedRange = NSRange(location: 6, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [.link: URL(string: "https://example.com")!]
        let editor = FolioRichTextEditor(
            attributedText: .constant(NSAttributedString(string: "linked")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        let linkedText = NSMutableAttributedString(string: "linked")
        linkedText.addAttributes(typingAttributes, range: NSRange(location: 0, length: linkedText.length))
        textView.attributedText = linkedText
        textView.selectedRange = NSRange(location: linkedText.length, length: 0)
        textView.typingAttributes = typingAttributes
        XCTAssertNotNil(textView.typingAttributes[.link])

        XCTAssertTrue(
            coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 6, length: 0),
                replacementText: " "
            )
        )

        XCTAssertNil(textView.typingAttributes[.link])
        XCTAssertNil(typingAttributes[.link])
    }

    func testCoordinatorClearsLinkTypingAttributeAfterReturn() {
        var selectedRange = NSRange(location: 6, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [.link: URL(string: "https://example.com")!]
        let editor = FolioRichTextEditor(
            attributedText: .constant(NSAttributedString(string: "linked")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        let linkedText = NSMutableAttributedString(string: "linked")
        linkedText.addAttributes(typingAttributes, range: NSRange(location: 0, length: linkedText.length))
        textView.attributedText = linkedText
        textView.selectedRange = NSRange(location: linkedText.length, length: 0)
        textView.typingAttributes = typingAttributes

        XCTAssertTrue(
            coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 6, length: 0),
                replacementText: "\n"
            )
        )

        XCTAssertNil(textView.typingAttributes[.link])
        XCTAssertNil(typingAttributes[.link])
    }

    func testEditorSynchronizesSelectionWhenContentIsAlreadyInSync() {
        XCTAssertTrue(
            FolioRichTextEditor.shouldSynchronizeSelection(
                current: NSRange(location: 0, length: 0),
                desired: NSRange(location: 4, length: 0),
                textLength: 4
            )
        )
    }

    func testTypedBlockquoteMarkerIsNotTreatedAsBlockquote() {
        let text = NSAttributedString(string: "> hello\n")
        let html = FolioRichTextEditor.htmlFromAttributedText(text)
        XCTAssertFalse(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("&gt; hello"))
    }

    func testRealBlockquoteRoundTripsToBlockquote() {
        let mutable = NSMutableAttributedString(string: "> cited text\n")
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.blockquoteIndent
        style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        mutable.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: mutable.length))

        let html = FolioRichTextEditor.htmlFromAttributedText(mutable)

        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)
        XCTAssertTrue(html.contains("<blockquote>cited text</blockquote>"))
        XCTAssertTrue(parsed.string.contains(FolioRichTextFormat.blockquoteMarker))
    }

    func testEmptyBlockquoteKeepsItsMarker() {
        let html = "<blockquote></blockquote>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertTrue(parsed.string.contains(FolioRichTextFormat.blockquoteMarker))

        let reserialized = FolioRichTextEditor.htmlFromAttributedText(parsed)
        XCTAssertTrue(reserialized.contains("<blockquote>"))
    }

    func testParagraphRoundTrips() {
        let text = NSAttributedString(string: "plain paragraph\n")
        let html = FolioRichTextEditor.htmlFromAttributedText(text)
        XCTAssertTrue(html.contains("<p>plain paragraph</p>"))
    }

    func testTrailingNewlineSerializesAsAnEmptyParagraph() {
        let text = NSAttributedString(string: "hello\n")

        XCTAssertEqual(
            FolioRichTextEditor.htmlFromAttributedText(text),
            "<p>hello</p>\n<p></p>"
        )
    }

    @MainActor
    func testHandledListEditPublishesBeforeUpdatingBinding() {
        var publishedHTML: String?
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: "\u{2022}\tfirst"),
            publishingHTML: { publishedHTML = $0 }
        )
        var selectedRange = NSRange(location: model.attributedText.length, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let editor = FolioRichTextEditor(
            attributedText: Binding(get: { model.attributedText }, set: { model.attributedText = $0 }),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { model.textChanged($0) }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = model.attributedText
        textView.selectedRange = selectedRange

        XCTAssertFalse(
            coordinator.textView(
                textView,
                shouldChangeTextIn: selectedRange,
                replacementText: "\n"
            )
        )
        XCTAssertEqual(publishedHTML, FolioRichTextEditor.htmlFromAttributedText(model.attributedText))
    }

    func testOrderedListWithBoldAndItalicKeepsBoldOnParse() {
        let html = "<ol><li><em>Hello</em></li><li><strong>world</strong></li>"
            + "<li><strong>Hi</strong></li><li>what</li><li>Are <strong>you</strong></li></ol>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertTrue(parsed.string.contains("Hello"))
        XCTAssertTrue(parsed.string.contains("world"))

        func isBold(characterAt index: Int) -> Bool {
            guard index < parsed.length else { return false }
            guard let font = parsed.attribute(.font, at: index, effectiveRange: nil) as? UIFont else {
                return false
            }
            return font.fontDescriptor.symbolicTraits.contains(.traitBold)
        }

        let helloRange = (parsed.string as NSString).range(of: "Hello")
        let worldRange = (parsed.string as NSString).range(of: "world")
        let hiRange = (parsed.string as NSString).range(of: "Hi")

        // "Hello" should be italic, not bold.
        XCTAssertFalse(isBold(characterAt: helloRange.location))
        // "world" and "Hi" should be bold.
        XCTAssertTrue(isBold(characterAt: worldRange.location))
        XCTAssertTrue(isBold(characterAt: hiRange.location))
    }

    func testEditorSavePreservesBoldAndItalicInOrderedList() {
        // Simulate an ordered list as the editor holds it in memory:
        // "1.\tHello(italic)\n2.\tworld(bold)\n3.\tHi(bold)\n4.\twhat\n5.\tAre you(bold)\n"
        let text = "1.\tHello\n2.\tworld\n3.\tHi\n4.\twhat\n5.\tAre you\n"
        let mutable = NSMutableAttributedString(string: text)
        let italicBody = UIFont.italicSystemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        let boldBody = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold)
        let attrs = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]

        // Markers get body font.
        mutable.setAttributes(attrs, range: NSRange(location: 0, length: text.count))
        let helloRange = (text as NSString).range(of: "Hello")
        mutable.addAttribute(.font, value: italicBody, range: helloRange)
        let worldRange = (text as NSString).range(of: "world")
        mutable.addAttribute(.font, value: boldBody, range: worldRange)
        let hiRange = (text as NSString).range(of: "Hi")
        mutable.addAttribute(.font, value: boldBody, range: hiRange)
        let youRange = (text as NSString).range(of: "you")
        mutable.addAttribute(.font, value: boldBody, range: youRange)

        let html = FolioRichTextEditor.htmlFromAttributedText(mutable)

        XCTAssertTrue(html.contains("<strong>world</strong>"), "Serialized HTML: \(html)")
        XCTAssertTrue(html.contains("<em>Hello</em>"))
        XCTAssertTrue(html.contains("<strong>you</strong>"))
    }

    func testParseNestedEmStrongKeepsBoldAndItalic() {
        // Exactly the HTML from the GET response: <em><strong>Hello</strong></em>
        let html = "<ol><li><em><strong>Hello</strong></em></li><li><strong>world</strong></li>"
            + "<li><strong>Hi</strong></li><li>what</li><li>Are <strong>you</strong></li></ol>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        let helloRange = (parsed.string as NSString).range(of: "Hello")
        XCTAssertNotEqual(helloRange.location, NSNotFound)

        guard let font = parsed.attribute(.font, at: helloRange.location, effectiveRange: nil) as? UIFont else {
            XCTFail("No font on Hello")
            return
        }
        let traits = font.fontDescriptor.symbolicTraits
        XCTAssertTrue(traits.contains(.traitBold), "Hello should be bold, traits=\(traits)")
        XCTAssertTrue(traits.contains(.traitItalic), "Hello should be italic, traits=\(traits)")
    }

    func testOrderedListWithBoldAndItalicRoundTrips() {
        let html = "<ol><li><em>Hello</em></li><li><strong>world</strong></li>"
            + "<li><strong>Hi</strong></li><li>what</li><li>Are <strong>you</strong></li></ol>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)
        let reserialized = FolioRichTextEditor.htmlFromAttributedText(parsed)

        XCTAssertTrue(reserialized.contains("<strong>world</strong>"))
        XCTAssertTrue(reserialized.contains("<em>Hello</em>"))
        XCTAssertTrue(reserialized.contains("<strong>Hi</strong>"))
    }

    func testBulletListRoundTripsToSemanticHTML() {
        let html = "<ul><li>first</li><li><strong>second</strong></li></ul>"

        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)
        let reserialized = FolioRichTextEditor.htmlFromAttributedText(parsed)

        XCTAssertEqual(reserialized, "<ul><li>first</li><li><strong>second</strong></li></ul>")
    }

    func testHyperlinkRoundTripsThroughSanitizedHTML() {
        let mutable = NSMutableAttributedString(string: "Folio")
        mutable.addAttribute(.link, value: URL(string: "https://folio.example")!, range: NSRange(location: 0, length: 5))

        let html = FolioRichTextEditor.htmlFromAttributedText(mutable)
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertEqual(html, "<p><a href=\"https://folio.example\">Folio</a></p>")
        XCTAssertEqual((parsed.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString, "https://folio.example")
    }

    func testParsedContentUsesTitleInputTextColor() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML("<p>Folio</p>")

        XCTAssertEqual(parsed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor(Color.folioInk))
    }

    func testUnsupportedHyperlinksAreNotParsedOrSerialized() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML("<p><a href=\"javascript:alert(1)\">unsafe</a></p>")
        let mutable = NSMutableAttributedString(string: "unsafe")
        mutable.addAttribute(.link, value: URL(string: "file:///private/unsafe")!, range: NSRange(location: 0, length: 6))

        XCTAssertNil(parsed.attribute(.link, at: 0, effectiveRange: nil))
        XCTAssertEqual(FolioRichTextEditor.htmlFromAttributedText(mutable), "<p>unsafe</p>")
    }

    func testFallbackHTMLParserRemovesUnsupportedHyperlinks() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML("<div><a href=\"javascript:alert(1)\">unsafe</a></div>")

        XCTAssertNil(parsed.attribute(.link, at: 0, effectiveRange: nil))
    }

    // MARK: shouldAllowTextEdit

    func testCaretInsertInsideMarkerIsRejected() {
        // "•\tmilk" — marker at (0, 2). Caret between "•"(0) and tab(1).
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertFalse(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 1, length: 0), markers: markers))
    }

    func testCaretInsertAtMarkerStartIsRejected() {
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertFalse(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 0, length: 0), markers: markers))
    }

    func testCaretInsertAfterMarkerIsAllowed() {
        // Caret at position 2 (after the tab) — not inside the marker.
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertTrue(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 2, length: 0), markers: markers))
    }

    func testSelectAllDeleteIsAllowed() {
        // Whole document selection covers the marker fully.
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertTrue(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 0, length: 10), markers: markers))
    }

    func testSelectionCoveringWholeMarkerIsAllowed() {
        let markers = [NSRange(location: 5, length: 2)]
        XCTAssertTrue(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 4, length: 4), markers: markers))
    }

    func testSelectionPartiallyOverlappingMarkerIsRejected() {
        let markers = [NSRange(location: 5, length: 2)]
        // Selects only the "•" (first char of the marker), leaving the tab behind.
        XCTAssertFalse(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 5, length: 1), markers: markers))
    }
}
