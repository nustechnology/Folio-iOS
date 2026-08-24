@testable import Folio
import UIKit
import XCTest

@MainActor
final class NotebookFormattingControllerTests: XCTestCase {
    func testToggleTraitAtEmptyCursorLeavesExistingTextUnchangedAndUpdatesTypingAttributes() {
        let text = NSAttributedString(
            string: "hello",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        let controller = NotebookFormattingController()

        let result = controller.toggleTrait(
            .traitBold,
            in: text,
            selectedRange: NSRange(location: 5, length: 0),
            appliesToTypingAttributes: true
        )

        XCTAssertEqual(result?.attributedText.string, "hello")
        let font = result?.typingAttributes?[.font] as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertEqual(result?.selectedRange, NSRange(location: 5, length: 0))
    }

    func testToggleTraitAtEmptyCursorRemovesPreviouslyAppliedTypingTrait() {
        let text = NSAttributedString(
            string: "hello",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        let controller = NotebookFormattingController()
        let cursor = NSRange(location: 5, length: 0)
        let firstResult = controller.toggleTrait(
            .traitBold,
            in: text,
            selectedRange: cursor,
            appliesToTypingAttributes: true
        )!

        let secondResult = controller.toggleTrait(
            .traitBold,
            in: text,
            selectedRange: cursor,
            currentTypingAttributes: firstResult.typingAttributes,
            appliesToTypingAttributes: true
        )

        let font = secondResult?.typingAttributes?[.font] as? UIFont
        XCTAssertFalse(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    func testToggleTraitOnMixedSelectionAppliesBoldToEveryCharacter() {
        let mutable = NSMutableAttributedString(
            string: "bold plain",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        mutable.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold),
            range: NSRange(location: 0, length: 4)
        )
        let controller = NotebookFormattingController()

        let result = controller.toggleTrait(.traitBold, in: mutable, selectedRange: NSRange(location: 0, length: mutable.length))

        XCTAssertTrue(controller.activeFormats(in: result!.attributedText, selectedRange: NSRange(location: 0, length: mutable.length)).isBold)
    }

    func testToggleTraitAddsBoldToSelectedTextWithoutAnExplicitFont() {
        let text = NSAttributedString(string: "plain")
        let controller = NotebookFormattingController()

        let result = controller.toggleTrait(.traitBold, in: text, selectedRange: NSRange(location: 0, length: text.length))

        XCTAssertTrue(controller.activeFormats(in: result!.attributedText, selectedRange: NSRange(location: 0, length: text.length)).isBold)
    }

    func testActiveFormatsUsesTypingAttributesAtAnEmptyCursor() {
        let controller = NotebookFormattingController()
        let typingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold)
        ]

        let state = controller.activeFormats(
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0),
            typingAttributes: typingAttributes
        )

        XCTAssertTrue(state.isBold)
    }

    func testApplyLinkPreservesSelectedRangeAndAddsLinkAttribute() {
        let text = NSAttributedString(string: "Folio")
        let controller = NotebookFormattingController()
        let selection = NSRange(location: 0, length: 5)

        let result = controller.applyLink(URL(string: "https://folio.example")!, in: text, selectedRange: selection)

        XCTAssertEqual(result?.selectedRange, selection)
        XCTAssertEqual((result?.attributedText.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString, "https://folio.example")
    }

    func testApplyLinkRejectsUnsupportedURLScheme() {
        let text = NSAttributedString(string: "Folio")
        let controller = NotebookFormattingController()

        let result = controller.applyLink(URL(string: "javascript:alert(1)")!, in: text, selectedRange: NSRange(location: 0, length: 5))

        XCTAssertNil(result)
    }

    func testListToggleFormatsAndRemovesEverySelectedParagraph() {
        let text = NSAttributedString(string: "first\nsecond\n")
        let controller = NotebookFormattingController()
        let selection = NSRange(location: 0, length: text.length)

        let formatted = controller.applyListStyle(ordered: false, in: text, selectedRange: selection)!
        let restored = controller.applyListStyle(ordered: false, in: formatted.attributedText, selectedRange: formatted.selectedRange!)!

        XCTAssertEqual(formatted.attributedText.string, "\u{2022}\tfirst\n\u{2022}\tsecond\n")
        XCTAssertEqual(restored.attributedText.string, "first\nsecond\n")
    }

    func testListParagraphPlacesMarkerAtTheEditorInset() {
        let text = NSAttributedString(string: "first")
        let controller = NotebookFormattingController()

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
        let controller = NotebookFormattingController()

        let result = controller.applyListStyle(
            ordered: false,
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "\u{2022}\t")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 2, length: 0))
    }

    func testNumberedListActionInEmptyEditorCreatesFirstItem() {
        let controller = NotebookFormattingController()

        let result = controller.applyListStyle(
            ordered: true,
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "1.\t")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 3, length: 0))
    }

    func testBulletListActionFormatsEmptyParagraphAfterNewline() {
        let controller = NotebookFormattingController()
        let text = NSAttributedString(string: "hello\n")

        let result = controller.applyListStyle(
            ordered: false,
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "hello\n\u{2022}\t")
    }

    func testNumberedListActionFormatsEmptyParagraphAfterNewline() {
        let controller = NotebookFormattingController()
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
        let controller = NotebookFormattingController()

        let state = controller.activeFormats(in: text, selectedRange: NSRange(location: 0, length: text.length))

        XCTAssertFalse(state.isUnorderedList)
        XCTAssertFalse(state.isOrderedList)
    }

    func testReturnAfterBulletItemCreatesAnotherBulletItem() {
        let text = NSAttributedString(string: "\u{2022}\tfirst")
        let controller = NotebookFormattingController()

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
        let controller = NotebookFormattingController()

        let result = controller.applyListEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        XCTAssertEqual(result?.attributedText.string, "1.\tfirst\n2.\t")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 12, length: 0))
    }

    func testReturnOnEmptyBulletItemExitsList() {
        let text = NSAttributedString(string: "\u{2022}\t")
        let controller = NotebookFormattingController()

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
        let controller = NotebookFormattingController()

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
        let controller = NotebookFormattingController()

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
        let controller = NotebookFormattingController()

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
        let controller = NotebookFormattingController()

        let result = controller.applyListEdit(
            replacementText: "",
            in: text,
            selectedRange: NSRange(location: 0, length: 4)
        )

        XCTAssertNil(result)
    }

    func testRemovingNumberedMarkerRenumbersNextOrderedList() {
        let text = NSAttributedString(string: "1.\tfirst\n2.\tsecond\n3.\tthird")
        let controller = NotebookFormattingController()

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
        let controller = NotebookFormattingController()

        let result = controller.applyListEdit(
            replacementText: "\n",
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )

        let font = result?.typingAttributes?[.font] as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

}
