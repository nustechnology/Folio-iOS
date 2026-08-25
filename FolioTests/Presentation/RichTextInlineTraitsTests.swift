@testable import Folio
import UIKit
import XCTest

@MainActor
final class RichTextInlineTraitsTests: XCTestCase {
    func testToggleTraitAtEmptyCursorLeavesExistingTextUnchangedAndUpdatesTypingAttributes() {
        let text = NSAttributedString(
            string: "hello",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        let controller = RichTextFormattingController()

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
        let controller = RichTextFormattingController()
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
        let controller = RichTextFormattingController()

        let result = controller.toggleTrait(.traitBold, in: mutable, selectedRange: NSRange(location: 0, length: mutable.length))

        XCTAssertTrue(controller.activeFormats(in: result!.attributedText, selectedRange: NSRange(location: 0, length: mutable.length)).isBold)
    }

    func testToggleTraitClampsStaleSelectionToTextLength() {
        let text = NSAttributedString(string: "plain")

        let result = RichTextFormattingController().toggleTrait(
            .traitBold,
            in: text,
            selectedRange: NSRange(location: 0, length: 100)
        )

        XCTAssertEqual(result?.selectedRange, NSRange(location: 0, length: text.length))
    }

    func testToggleTraitAddsBoldToSelectedTextWithoutAnExplicitFont() {
        let text = NSAttributedString(string: "plain")
        let controller = RichTextFormattingController()

        let result = controller.toggleTrait(.traitBold, in: text, selectedRange: NSRange(location: 0, length: text.length))

        XCTAssertTrue(controller.activeFormats(in: result!.attributedText, selectedRange: NSRange(location: 0, length: text.length)).isBold)
    }

    func testActiveFormatsUsesTypingAttributesAtAnEmptyCursor() {
        let controller = RichTextFormattingController()
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

    func testActiveFormatsUsesFontTraitForBoldTypingAttributesWhenTextExists() {
        let controller = RichTextFormattingController()
        let typingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold)
        ]

        let state = controller.activeFormats(
            in: NSAttributedString(string: "existing"),
            selectedRange: NSRange(location: 8, length: 0),
            typingAttributes: typingAttributes
        )

        XCTAssertTrue(state.isBold)
    }

    func testActiveFormatsDetectsInlineBoldAtTheStartOfAHeadingRun() {
        let mutable = NSMutableAttributedString(
            string: "NUS TECHNOLOGY",
            attributes: [.font: UIFont.systemFont(
                ofSize: FolioRichTextFormat.heading1FontSize,
                weight: FolioRichTextFormat.heading1FontWeight
            )]
        )
        mutable.addAttribute(
            FolioRichTextFormat.inlineBoldAttribute,
            value: true,
            range: NSRange(location: 4, length: 10)
        )
        let state = RichTextFormattingController().activeFormats(
            in: mutable,
            selectedRange: NSRange(location: 4, length: 0),
            typingAttributes: mutable.attributes(at: 3, effectiveRange: nil)
        )

        XCTAssertTrue(state.isBold)
    }

    func testApplyLinkPreservesSelectedRangeAndAddsLinkAttribute() {
        let text = NSAttributedString(string: "Folio")
        let controller = RichTextFormattingController()
        let selection = NSRange(location: 0, length: 5)

        let result = controller.applyLink(URL(string: "https://folio.example")!, in: text, selectedRange: selection)

        XCTAssertEqual(result?.selectedRange, selection)
        XCTAssertEqual((result?.attributedText.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString, "https://folio.example")
    }

    func testApplyLinkRejectsUnsupportedURLScheme() {
        let text = NSAttributedString(string: "Folio")
        let controller = RichTextFormattingController()

        let result = controller.applyLink(URL(string: "javascript:alert(1)")!, in: text, selectedRange: NSRange(location: 0, length: 5))

        XCTAssertNil(result)
    }
}
