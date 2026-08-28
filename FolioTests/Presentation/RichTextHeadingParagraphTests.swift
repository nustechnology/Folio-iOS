@testable import Folio
import UIKit
import XCTest

@MainActor
final class RichTextHeadingParagraphTests: XCTestCase {
    func testApplyingHeadingUsesConfiguredHeadingWeight() {
        let controller = RichTextFormattingController()

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading2FontSize,
            in: NSAttributedString(string: "Heading"),
            selectedRange: NSRange(location: 0, length: "Heading".count)
        )!
        let font = result.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont

        XCTAssertEqual(
            font?.fontDescriptor.postscriptName,
            UIFont.systemFont(ofSize: FolioRichTextFormat.heading2FontSize, weight: .medium).fontDescriptor.postscriptName
        )
    }

    func testApplyingHeadingAtEmptyParagraphAfterNewlineUpdatesTypingAttributes() {
        let text = NSAttributedString(string: "First line\n")
        let controller = RichTextFormattingController()

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading2FontSize,
            in: text,
            selectedRange: NSRange(location: text.length, length: 0),
            currentTypingAttributes: [:]
        )!

        XCTAssertEqual(result.attributedText.string, text.string)
        XCTAssertEqual(
            (result.typingAttributes?[.font] as? UIFont)?.pointSize,
            FolioRichTextFormat.heading2FontSize
        )
    }

    func testApplyingEachHeadingAtMiddleEmptyParagraphUpdatesTypingAttributes() {
        let text = NSAttributedString(string: "nustechnology\n\nnustechnology")
        let cursor = NSRange(location: "nustechnology\n".count, length: 0)
        let controller = RichTextFormattingController()

        for (fontSize, headingLevel) in [
            (FolioRichTextFormat.heading1FontSize, 1),
            (FolioRichTextFormat.heading2FontSize, 2),
            (FolioRichTextFormat.heading3FontSize, 3)
        ] {
            let result = controller.applyHeading(
                fontSize: fontSize,
                in: text,
                selectedRange: cursor,
                currentTypingAttributes: [:]
            )!

            XCTAssertEqual((result.typingAttributes?[.font] as? UIFont)?.pointSize, fontSize)
            let state = controller.activeFormats(
                in: result.attributedText,
                selectedRange: result.selectedRange!,
                typingAttributes: result.typingAttributes ?? [:]
            )
            XCTAssertEqual(
                [state.isHeading1, state.isHeading2, state.isHeading3][headingLevel - 1],
                true
            )
        }
    }

    func testApplyingActiveHeadingAtEmptyCaretReturnsBodyTypingAttributes() {
        let controller = RichTextFormattingController()
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.heading1FontSize, weight: .bold)
        ]

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading1FontSize,
            in: NSAttributedString(string: ""),
            selectedRange: NSRange(location: 0, length: 0),
            currentTypingAttributes: headingAttributes
        )!

        XCTAssertEqual(
            (result.typingAttributes?[.font] as? UIFont)?.pointSize,
            FolioRichTextFormat.bodyFontSize
        )
    }

    func testSplittingHeadingAtEndResetsNewParagraphToBodyStyle() {
        let text = NSAttributedString(
            string: "Heading",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.heading2FontSize, weight: .bold)]
        )
        let result = RichTextFormattingController().splitParagraphAfterHeading(in: text, at: text.length)!
        let newParagraphFont = result.attributedText.attribute(.font, at: text.length, effectiveRange: nil) as? UIFont

        XCTAssertEqual(result.attributedText.string, "Heading\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: text.length + 1, length: 0))
        XCTAssertEqual(newParagraphFont?.pointSize, FolioRichTextFormat.bodyFontSize)
        XCTAssertEqual((result.typingAttributes?[.font] as? UIFont)?.pointSize, FolioRichTextFormat.bodyFontSize)
    }

    func testSplittingHeadingInMiddleIsRejected() {
        let text = NSAttributedString(
            string: "Heading",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.heading2FontSize, weight: .bold)]
        )

        XCTAssertNil(RichTextFormattingController().splitParagraphAfterHeading(in: text, at: 3))
    }

    func testApplyHeadingPreservesSelectedRange() {
        let text = NSAttributedString(string: "heading")
        let selection = NSRange(location: 1, length: 4)
        let controller = RichTextFormattingController()

        let result = controller.applyHeading(
            fontSize: FolioRichTextFormat.heading2FontSize,
            in: text,
            selectedRange: selection
        )

        XCTAssertEqual(result?.selectedRange, selection)
    }
}
