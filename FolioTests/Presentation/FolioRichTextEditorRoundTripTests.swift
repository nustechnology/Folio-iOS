@testable import Folio
import XCTest
import UIKit

final class FolioRichTextEditorRoundTripTests: XCTestCase {
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
