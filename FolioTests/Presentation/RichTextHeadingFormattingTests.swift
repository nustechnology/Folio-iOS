@testable import Folio
import UIKit
import XCTest

@MainActor
final class RichTextHeadingFormattingTests: XCTestCase {
    func testActiveFormatsHighlightsTheSelectedHeadingLevel() {
        let text = NSAttributedString(
            string: "Heading",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.heading2FontSize, weight: .bold)]
        )
        let controller = RichTextFormattingController()

        let state = controller.activeFormats(
            in: text,
            selectedRange: NSRange(location: 0, length: text.length)
        )

        XCTAssertFalse(state.isHeading1)
        XCTAssertTrue(state.isHeading2)
        XCTAssertFalse(state.isHeading3)
    }

    func testActiveFormatsDoesNotTreatHeadingFontAsInlineBold() {
        let text = NSAttributedString(
            string: "Heading",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.heading2FontSize, weight: .bold)]
        )
        let state = RichTextFormattingController().activeFormats(
            in: text,
            selectedRange: NSRange(location: 0, length: text.length)
        )

        XCTAssertTrue(state.isHeading2)
        XCTAssertFalse(state.isBold)
    }

    func testActiveFormatsTreatsExplicitBoldRunInsideHeadingAsBold() {
        let mutable = NSMutableAttributedString(
            string: "Heading",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.heading2FontSize, weight: .bold)]
        )
        mutable.addAttribute(
            FolioRichTextFormat.inlineBoldAttribute,
            value: true,
            range: NSRange(location: 0, length: mutable.length)
        )
        let state = RichTextFormattingController().activeFormats(
            in: mutable,
            selectedRange: NSRange(location: 0, length: mutable.length)
        )

        XCTAssertTrue(state.isHeading2)
        XCTAssertTrue(state.isBold)
    }

    func testTogglingBoldOffAtHeadingCaretKeepsHeadingActiveAndClearsBold() {
        let headingFont = UIFont.systemFont(
            ofSize: FolioRichTextFormat.heading1FontSize,
            weight: FolioRichTextFormat.heading1FontWeight
        )
        let typed = NSMutableAttributedString(
            string: "abc",
            attributes: [.font: headingFont, FolioRichTextFormat.inlineBoldAttribute: true]
        )
        let typingAttributes: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            FolioRichTextFormat.inlineBoldAttribute: true
        ]
        let controller = RichTextFormattingController()

        let result = controller.toggleTrait(
            .traitBold,
            in: typed,
            selectedRange: NSRange(location: typed.length, length: 0),
            currentTypingAttributes: typingAttributes,
            appliesToTypingAttributes: true
        )!

        let state = controller.activeFormats(
            in: result.attributedText,
            selectedRange: result.selectedRange!,
            typingAttributes: result.typingAttributes ?? [:]
        )
        XCTAssertTrue(state.isHeading1)
        XCTAssertFalse(state.isBold)
        XCTAssertFalse(
            result.attributedText.attribute(
                FolioRichTextFormat.inlineBoldAttribute,
                at: 0,
                effectiveRange: nil
            ) as? Bool == true
        )
        let font = result.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.heading1FontSize)
    }

    func testToggleBoldAppliesInlineBoldToEntireHeadingSelection() {
        let text = NSAttributedString(
            string: "NUS TECHNOLOGY",
            attributes: [.font: UIFont.systemFont(
                ofSize: FolioRichTextFormat.heading1FontSize,
                weight: FolioRichTextFormat.heading1FontWeight
            )]
        )
        let controller = RichTextFormattingController()

        let result = controller.toggleTrait(
            .traitBold,
            in: text,
            selectedRange: NSRange(location: 0, length: text.length)
        )!

        XCTAssertTrue(
            controller.activeFormats(
                in: result.attributedText,
                selectedRange: result.selectedRange!
            ).isBold
        )
        XCTAssertTrue(
            result.attributedText.attribute(
                FolioRichTextFormat.inlineBoldAttribute,
                at: 0,
                effectiveRange: nil
            ) as? Bool == true
        )
        let font = result.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertEqual(
            font?.fontDescriptor.postscriptName,
            UIFont.systemFont(ofSize: FolioRichTextFormat.heading1FontSize, weight: .bold).fontDescriptor.postscriptName
        )
    }
}

@MainActor
final class RichTextHeadingApplicationTests: XCTestCase {
    func testApplyingHeadingMakesThatHeadingLevelActive() {
        let text = NSAttributedString(
            string: "Heading",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        let controller = RichTextFormattingController()
        let selection = NSRange(location: 0, length: text.length)

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading2FontSize,
            in: text,
            selectedRange: selection
        )!
        let state = controller.activeFormats(in: result.attributedText, selectedRange: result.selectedRange!)

        XCTAssertFalse(state.isHeading1)
        XCTAssertTrue(state.isHeading2)
        XCTAssertFalse(state.isHeading3)
    }

    func testApplyingHeadingClampsStaleSelectionToTextLength() {
        let text = NSAttributedString(string: "Heading")

        let result = RichTextFormattingController().applyHeading(
            fontSize: FolioRichTextFormat.heading2FontSize,
            in: text,
            selectedRange: NSRange(location: 0, length: 100)
        )

        XCTAssertEqual(result?.selectedRange, NSRange(location: 0, length: text.length))
    }

    func testItalicKeepsH2AndH3Active() {
        let controller = RichTextFormattingController()

        for (fontSize, expectedHeading) in [
            (FolioRichTextFormat.heading2FontSize, 2),
            (FolioRichTextFormat.heading3FontSize, 3)
        ] {
            let source = NSAttributedString(
                string: "Heading",
                attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
            )
            let heading = controller.applyHeading(
                fontSize: fontSize,
                in: source,
                selectedRange: NSRange(location: 0, length: source.length)
            )!
            let italic = controller.toggleTrait(
                .traitItalic,
                in: heading.attributedText,
                selectedRange: heading.selectedRange!
            )!

            let state = controller.activeFormats(
                in: italic.attributedText,
                selectedRange: italic.selectedRange!
            )
            XCTAssertEqual(
                [state.isHeading1, state.isHeading2, state.isHeading3][expectedHeading - 1],
                true
            )
            XCTAssertTrue(state.isItalic)
        }
    }

    func testBoldAfterItalicKeepsItalicActiveForEveryHeadingLevel() {
        let controller = RichTextFormattingController()

        for fontSize in [
            FolioRichTextFormat.heading1FontSize,
            FolioRichTextFormat.heading2FontSize,
            FolioRichTextFormat.heading3FontSize
        ] {
            let source = NSAttributedString(
                string: "Heading",
                attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
            )
            let heading = controller.applyHeading(
                fontSize: fontSize,
                in: source,
                selectedRange: NSRange(location: 0, length: source.length)
            )!
            let italic = controller.toggleTrait(
                .traitItalic,
                in: heading.attributedText,
                selectedRange: heading.selectedRange!
            )!
            let bold = controller.toggleTrait(
                .traitBold,
                in: italic.attributedText,
                selectedRange: italic.selectedRange!
            )!

            let state = controller.activeFormats(
                in: bold.attributedText,
                selectedRange: bold.selectedRange!
            )
            XCTAssertTrue(state.isItalic)
            XCTAssertTrue(state.isBold)
        }
    }

    func testApplyingHeadingAtCaretUpdatesHeadingTypingAttributes() {
        let text = NSAttributedString(
            string: "Heading",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        let controller = RichTextFormattingController()

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading2FontSize,
            in: text,
            selectedRange: NSRange(location: text.length, length: 0)
        )!
        let font = result.typingAttributes?[.font] as? UIFont

        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.heading2FontSize)
    }

    func testApplyingHeadingAtEmptyNotebookUpdatesTypingAttributes() {
        let controller = RichTextFormattingController()

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading1FontSize,
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0),
            currentTypingAttributes: [:]
        )!

        XCTAssertEqual(result.attributedText.string, "")
        XCTAssertEqual(
            (result.typingAttributes?[.font] as? UIFont)?.pointSize,
            FolioRichTextFormat.heading1FontSize
        )
        XCTAssertTrue(
            controller.activeFormats(
                in: result.attributedText,
                selectedRange: result.selectedRange!,
                typingAttributes: result.typingAttributes ?? [:]
            ).isHeading1
        )
    }

    func testActiveFormatsDoesNotTreatEmptyHeadingTypingAttributesAsBold() {
        let controller = RichTextFormattingController()
        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading1FontSize,
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0),
            currentTypingAttributes: [:]
        )!

        let state = controller.activeFormats(
            in: result.attributedText,
            selectedRange: result.selectedRange!,
            typingAttributes: result.typingAttributes!
        )

        XCTAssertFalse(state.isBold)
        XCTAssertTrue(state.isHeading1)
    }

    func testBoldAfterApplyingHeadingMakesFutureTypingFontBold() {
        let controller = RichTextFormattingController()

        for fontSize in [
            FolioRichTextFormat.heading1FontSize,
            FolioRichTextFormat.heading2FontSize,
            FolioRichTextFormat.heading3FontSize
        ] {
            let heading = controller.applyHeading(
                fontSize: fontSize,
                in: NSAttributedString(string: ""),
                selectedRange: NSRange(location: 0, length: 0),
                currentTypingAttributes: [:]
            )!
            let bold = controller.toggleTrait(
                .traitBold,
                in: heading.attributedText,
                selectedRange: heading.selectedRange!,
                currentTypingAttributes: heading.typingAttributes,
                appliesToTypingAttributes: true
            )!

            let font = bold.typingAttributes?[.font] as? UIFont
            XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
            XCTAssertEqual(font?.pointSize, fontSize)
            XCTAssertEqual(
                font?.fontDescriptor.postscriptName,
                UIFont.systemFont(ofSize: fontSize, weight: FolioRichTextFormat.inlineBoldFontWeight)
                    .fontDescriptor.postscriptName
            )
        }
    }

    func testTogglingHeadingOffPreservesBoldAndItalic() {
        let controller = RichTextFormattingController()
        let source = NSAttributedString(string: "Research Objective")
        let h3Result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading3FontSize,
            in: source,
            selectedRange: NSRange(location: 0, length: source.length)
        )!
        let italicResult = controller.toggleTrait(
            .traitItalic,
            in: h3Result.attributedText,
            selectedRange: h3Result.selectedRange!
        )!
        let boldItalicResult = controller.toggleTrait(
            .traitBold,
            in: italicResult.attributedText,
            selectedRange: italicResult.selectedRange!
        )!

        // Ensure H3, Bold, and Italic are all active
        let h3State = controller.activeFormats(
            in: boldItalicResult.attributedText,
            selectedRange: boldItalicResult.selectedRange!
        )
        XCTAssertTrue(h3State.isHeading3)
        XCTAssertTrue(h3State.isBold)
        XCTAssertTrue(h3State.isItalic)

        // Toggle H3 off -> should return to body text with bold and italic preserved
        let plainResult = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading3FontSize,
            in: boldItalicResult.attributedText,
            selectedRange: boldItalicResult.selectedRange!
        )!

        let finalState = controller.activeFormats(
            in: plainResult.attributedText,
            selectedRange: plainResult.selectedRange!
        )
        XCTAssertFalse(finalState.isHeading3)
        XCTAssertTrue(finalState.isBold)
        XCTAssertTrue(finalState.isItalic)

        let font = plainResult.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.bodyFontSize)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
    }
}
