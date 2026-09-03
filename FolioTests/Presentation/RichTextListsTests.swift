@testable import Folio
import UIKit
import XCTest

@MainActor
final class RichTextListsTests: XCTestCase {
    func testListToggleFormatsAndRemovesEverySelectedParagraph() {
        let text = NSAttributedString(string: "first\nsecond\n")
        let controller = RichTextFormattingController()
        let selection = NSRange(location: 0, length: text.length)

        let formatted = controller.applyListStyle(ordered: false, in: text, selectedRange: selection)!
        let restored = controller.applyListStyle(ordered: false, in: formatted.attributedText, selectedRange: formatted.selectedRange!)!

        XCTAssertEqual(formatted.attributedText.string, "\u{2022}\tfirst\n\u{2022}\tsecond\n")
        XCTAssertEqual(restored.attributedText.string, "first\nsecond\n")
    }

    func testListParagraphPlacesMarkerAtTheEditorInset() {
        let text = NSAttributedString(string: "first")
        let controller = RichTextFormattingController()

        let formatted = controller.applyListStyle(
            ordered: false,
            in: text,
            selectedRange: NSRange(location: 0, length: text.length)
        )!
        let paragraphStyle = formatted.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle

        XCTAssertEqual(paragraphStyle?.headIndent, FolioRichTextFormat.listIndent)
        XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, 0)
    }

    func testBulletActionInEmptyEditorCreatesFirstItem() {
        let controller = RichTextFormattingController()

        let result = controller.applyListStyle(
            ordered: false,
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "\u{2022}\t")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 2, length: 0))
    }

    func testNumberedListActionInEmptyEditorCreatesFirstItem() {
        let controller = RichTextFormattingController()

        let result = controller.applyListStyle(
            ordered: true,
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "1.\t")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 3, length: 0))
    }

    func testBulletListActionFormatsEmptyParagraphAfterNewline() {
        let controller = RichTextFormattingController()
        let text = NSAttributedString(string: "hello\n")

        let result = controller.applyListStyle(
            ordered: false,
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "hello\n\u{2022}\t")
    }

    func testNumberedListActionFormatsEmptyParagraphAfterNewline() {
        let controller = RichTextFormattingController()
        let text = NSAttributedString(string: "hello\n")

        let result = controller.applyListStyle(
            ordered: true,
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "hello\n1.\t")
    }

    func testActiveFormatsRequiresEverySelectedParagraphToUseSameListType() {
        let text = NSAttributedString(string: "\u{2022}\tfirst\n2.\tsecond\n")
        let controller = RichTextFormattingController()

        let state = controller.activeFormats(in: text, selectedRange: NSRange(location: 0, length: text.length))

        XCTAssertFalse(state.isUnorderedList)
        XCTAssertFalse(state.isOrderedList)
    }

    func testReturnAfterBulletItemCreatesAnotherBulletItem() {
        let text = NSAttributedString(string: "\u{2022}\tfirst")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "\u{2022}\tfirst\n\u{2022}\t")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 10, length: 0))
    }

    func testReturnAfterNumberedItemCreatesNextNumber() {
        let text = NSAttributedString(string: "1.\tfirst")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "1.\tfirst\n2.\t")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 12, length: 0))
    }

    func testHeadingAfterNumberedItemEnterUpdatesTypingAttributesForNewItem() {
        let text = NSAttributedString(
            string: "first",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        let controller = RichTextFormattingController()

        let listResult = controller.applyListStyle(
            ordered: true,
            in: text,
            selectedRange: NSRange(location: 0, length: text.length)
        )!
        let itemResult = controller.applyListEdit(
            replacementText: "\n",
            in: listResult.attributedText,
            selectedRange: NSRange(location: listResult.attributedText.length, length: 0)
        )!
        let headingResult = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading1FontSize,
            in: itemResult.attributedText,
            selectedRange: itemResult.selectedRange!,
            currentTypingAttributes: itemResult.typingAttributes ?? [:]
        )!

        let font = headingResult.typingAttributes?[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.heading1FontSize)
        let markerFont = headingResult.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(markerFont?.pointSize, FolioRichTextFormat.bodyFontSize)
        XCTAssertTrue(
            controller.activeFormats(
                in: headingResult.attributedText,
                selectedRange: headingResult.selectedRange!,
                typingAttributes: headingResult.typingAttributes ?? [:]
            ).isHeading1
        )
    }

    func testReturnOnEmptyBulletItemExitsList() {
        let text = NSAttributedString(string: "\u{2022}\t")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 0, length: 0))
    }

    func testBackspaceAfterNumberedMarkerRemovesCompleteMarker() {
        let text = NSAttributedString(string: "1.\tfirst")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "",
            in: text,
            selectedRange: NSRange(location: 2, length: 1)
        )

        XCTAssertEqual(result?.attributedText.string, "first")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 0, length: 0))
    }

    func testReturnWithinOrderedListRenumbersFollowingItems() {
        let text = NSAttributedString(string: "1.\tfirst\n2.\tsecond")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: 8, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "1.\tfirst\n2.\t\n3.\tsecond")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 12, length: 0))
    }

    func testDeleteAtBulletMarkerRemovesCompleteMarker() {
        let text = NSAttributedString(string: "\u{2022}\tfirst")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "",
            in: text,
            selectedRange: NSRange(location: 0, length: 1)
        )

        XCTAssertEqual(result?.attributedText.string, "first")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 0, length: 0))
    }

    func testDeletingMarkerAndItemTextFallsBackToTextViewDeletion() {
        let text = NSAttributedString(string: "\u{2022}\tfirst")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "",
            in: text,
            selectedRange: NSRange(location: 0, length: 4)
        )

        XCTAssertNil(result)
    }

    func testRemovingNumberedMarkerRenumbersNextOrderedList() {
        let text = NSAttributedString(string: "1.\tfirst\n2.\tsecond\n3.\tthird")
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "",
            in: text,
            selectedRange: NSRange(location: 9, length: 1)
        )

        XCTAssertEqual(result?.attributedText.string, "1.\tfirst\nsecond\n1.\tthird")
    }

    func testReturnInBoldBulletPreservesTypingAttributes() {
        let text = NSMutableAttributedString(string: "\u{2022}\tbold")
        text.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold),
            range: NSRange(location: 2, length: 4)
        )
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        let font = result?.typingAttributes?[.font] as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    func testReplacingListMarkerWithTextResetsParagraphIndentation() {
        let text = NSAttributedString(string: "\u{2022}\tfirst")
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.listIndent
        style.firstLineHeadIndent = 0
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: mutable.length))
        let controller = RichTextFormattingController()

        let result = controller.applyListEdit(
            replacementText: "replacement",
            in: mutable,
            selectedRange: NSRange(location: 0, length: mutable.length)
        )

        XCTAssertEqual(result?.attributedText.string, "replacement")
        let paragraphStyle = result?.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.headIndent, 0)
        XCTAssertEqual(result?.selectedRange, NSRange(location: "replacement".count, length: 0))
    }

    func testApplyHeadingRemovesListItemMarkerAndAppliesHeadingFont() {
        let text = NSAttributedString(string: "1.\tHi\n2.\tHow\n3.\tWhat\n4.\tDo")
        let controller = RichTextFormattingController()

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading1FontSize,
            in: text,
            selectedRange: NSRange(location: 7, length: 0)
        )

        XCTAssertNotNil(result)
        let formattedString = result!.attributedText.string
        XCTAssertTrue(formattedString.contains("1.\tHi\nHow\n"))

        let howRange = (formattedString as NSString).range(of: "How")
        let font = result!.attributedText.attribute(.font, at: howRange.location, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.heading1FontSize)

        let html = FolioRichTextEditor.htmlFromAttributedText(result!.attributedText)
        XCTAssertTrue(html.contains("<h1>How</h1>"))
        XCTAssertFalse(html.contains("<li><strong>How</strong></li>"))
    }

    func testApplyListStyleOnHeadingResetsFontToBodyAndAddsMarker() {
        let mutable = NSMutableAttributedString(string: "How")
        let headingFont = UIFont.systemFont(ofSize: FolioRichTextFormat.heading1FontSize, weight: .bold)
        mutable.addAttribute(.font, value: headingFont, range: NSRange(location: 0, length: 3))

        let controller = RichTextFormattingController()
        let result = controller.applyListStyle(
            ordered: true,
            in: mutable,
            selectedRange: NSRange(location: 0, length: 3)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.attributedText.string, "1.\tHow")
        let howRange = (result!.attributedText.string as NSString).range(of: "How")
        let font = result!.attributedText.attribute(.font, at: howRange.location, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.bodyFontSize)

        let html = FolioRichTextEditor.htmlFromAttributedText(result!.attributedText)
        XCTAssertEqual(html, "<ol><li>How</li></ol>")
    }
}
