@testable import Folio
import UIKit
import XCTest

@MainActor
final class RichTextBlockquoteTests: XCTestCase {
    func testApplyBlockquotePreservesSelectedRange() {
        let text = NSAttributedString(string: "quote")
        let selection = NSRange(location: 1, length: 3)
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquote(in: text, selectedRange: selection)

        XCTAssertEqual(result?.selectedRange, NSRange(location: selection.location + 2, length: selection.length))
    }

    func testBackspaceAfterEmptyBlockquoteMarkerRemovesTheBlockquote() {
        let text = quotedText("")
        let controller = RichTextFormattingController()

        let result = controller.removeEmptyBlockquote(
            in: text,
            editRange: NSRange(location: 1, length: 1)
        )

        XCTAssertEqual(result?.attributedText.string, "")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 0, length: 0))
    }

    func testEnterInBlockquoteContinuesTheBlockquote() {
        let text = quotedText("quote")
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquoteEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "> quote\n> ")
        XCTAssertEqual(result?.selectedRange, NSRange(location: text.length + 3, length: 0))
        let continuedStyle = result?.attributedText.attribute(.paragraphStyle, at: text.length + 1, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(continuedStyle?.headIndent, FolioRichTextFormat.blockquoteIndent)
    }

    func testEnterInBlockquoteKeepsBodyTypingAttributesForTheNewLine() {
        let text = NSMutableAttributedString(
            attributedString: quotedText("quote")
        )
        text.addAttributes([
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize),
            .foregroundColor: UIColor.black
        ], range: NSRange(location: 0, length: text.length))
        text.addAttributes([
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.hiddenMarkerFontSize),
            .foregroundColor: UIColor.clear
        ], range: NSRange(location: 0, length: (FolioRichTextFormat.blockquoteMarker as NSString).length))
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquoteEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        let font = result?.typingAttributes?[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.bodyFontSize)
        XCTAssertFalse(result?.typingAttributes?[.foregroundColor] as? UIColor == .clear)
    }

    func testEnterOnEmptyBlockquoteExitsTheBlockquote() {
        let text = quotedText("")
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquoteEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "\n")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 0, length: 0))
        let plainStyle = result?.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(plainStyle?.headIndent, 0)
    }

    func testEnterOnEmptyBlockquoteBetweenParagraphsKeepsOneEmptyParagraph() {
        let text = NSMutableAttributedString(string: "a\n> \nb")
        let quoteStyle = NSMutableParagraphStyle()
        quoteStyle.headIndent = FolioRichTextFormat.blockquoteIndent
        quoteStyle.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        text.addAttribute(.paragraphStyle, value: quoteStyle, range: NSRange(location: 2, length: 3))
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquoteEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: 4, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "a\n\nb")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertEqual(result?.attributedText.string.components(separatedBy: "\n").count, 3)
    }

    func testActiveFormatsIsInactiveAtTheStartOfPlainParagraphAfterBlockquote() {
        let text = NSMutableAttributedString(string: "> quote\n\n")
        let quoteStyle = NSMutableParagraphStyle()
        quoteStyle.headIndent = FolioRichTextFormat.blockquoteIndent
        quoteStyle.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        text.addAttribute(.paragraphStyle, value: quoteStyle, range: NSRange(location: 0, length: 7))
        let plainStyle = NSMutableParagraphStyle()
        text.addAttribute(.paragraphStyle, value: plainStyle, range: NSRange(location: 7, length: 1))

        let state = RichTextFormattingController().activeFormats(
            in: text,
            selectedRange: NSRange(location: 8, length: 0)
        )

        XCTAssertFalse(state.isBlockquote)
    }

    func testExitingEmptyBlockquoteRestoresBodyTypingFont() {
        let text = NSMutableAttributedString(attributedString: quotedText(""))
        text.addAttributes([
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.hiddenMarkerFontSize),
            .foregroundColor: UIColor.clear
        ], range: NSRange(location: 0, length: text.length))
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquoteEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        let font = result?.typingAttributes?[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.bodyFontSize)
    }

    func testActiveFormatsReportsBlockquoteForQuotedCaret() {
        let text = quotedText("quote")
        let state = RichTextFormattingController().activeFormats(
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertTrue(state.isBlockquote)
    }

    func testActiveFormatsReportsBlockquoteOnlyWhenEverySelectedParagraphIsQuoted() {
        let text = NSMutableAttributedString(attributedString: quotedText("first\nsecond"))
        text.replaceCharacters(in: NSRange(location: 8, length: 2), with: "")
        let controller = RichTextFormattingController()

        let state = controller.activeFormats(
            in: text,
            selectedRange: NSRange(location: 0, length: text.length)
        )

        XCTAssertFalse(state.isBlockquote, "text=\(text.string)")
    }

    func testApplyBlockquoteTogglesAllSelectedParagraphs() {
        let text = NSAttributedString(string: "first\nsecond")
        let controller = RichTextFormattingController()

        let quoted = controller.applyBlockquote(
            in: text,
            selectedRange: NSRange(location: 0, length: text.length)
        )
        let unquoted = controller.applyBlockquote(
            in: quoted!.attributedText,
            selectedRange: quoted!.selectedRange!
        )

        XCTAssertEqual(quoted?.attributedText.string, "> first\n> second", "quoted=\(quoted?.attributedText.string ?? "nil")")
        XCTAssertEqual(unquoted?.attributedText.string, text.string, "unquoted=\(unquoted?.attributedText.string ?? "nil")")
    }

    func testApplyBlockquotePreservesFullMultiParagraphSelection() {
        let source = NSAttributedString(string: "first\nsecond")
        let selection = NSRange(location: 0, length: source.length)
        let controller = RichTextFormattingController()

        let quoted = controller.applyBlockquote(in: source, selectedRange: selection)!
        let unquoted = controller.applyBlockquote(
            in: quoted.attributedText,
            selectedRange: quoted.selectedRange!
        )!

        XCTAssertEqual(quoted.selectedRange, NSRange(location: 2, length: source.length + 2))
        XCTAssertEqual(unquoted.selectedRange, selection)
    }

    func testApplyBlockquoteCreatesQuoteForEmptyEditor() {
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquote(
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, FolioRichTextFormat.blockquoteMarker)
        XCTAssertEqual(result?.selectedRange, NSRange(location: 2, length: 0))
        let style = result?.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent, FolioRichTextFormat.blockquoteIndent)
    }

    func testApplyBlockquoteFormatsEmptyParagraphAfterTrailingNewline() {
        let controller = RichTextFormattingController()

        let result = controller.applyBlockquote(
            in: NSAttributedString(string: "plain\n"),
            selectedRange: NSRange(location: 6, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "plain\n> ")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 8, length: 0))
        let style = result?.attributedText.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent, FolioRichTextFormat.blockquoteIndent)
    }
}
