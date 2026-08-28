import SwiftUI
import UIKit

@MainActor
extension RichTextFormattingController {
    func applyHeading(
        fontSize: CGFloat,
        in attributedText: NSAttributedString,
        selectedRange: NSRange,
        currentTypingAttributes: [NSAttributedString.Key: Any] = [:]
    ) -> Result? {
        let clampedSelectedRange = clampedSelection(selectedRange, to: attributedText.length)
        if clampedSelectedRange.length == 0 {
            let paragraph = paragraphRange(at: clampedSelectedRange.location, in: attributedText)
            let paragraphText = paragraph.location == NSNotFound
                ? ""
                : (attributedText.string as NSString).substring(with: paragraph)
                    .trimmingCharacters(in: .newlines)
            if paragraphText.isEmpty {
                return headingTypingResult(
                    fontSize: fontSize,
                    attributedText: attributedText,
                    selectedRange: clampedSelectedRange,
                    currentTypingAttributes: currentTypingAttributes
                )
            }
        }

        let selectionRange = clampedSelectedRange.length > 0
            ? clampedSelectedRange
            : paragraphRange(at: clampedSelectedRange.location, in: attributedText)
        guard selectionRange.location != NSNotFound else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let nsString = mutable.string as NSString
        let paragraphs = paragraphRanges(in: selectionRange, string: nsString)
        guard !paragraphs.isEmpty else { return nil }

        let allMatch = paragraphs.allSatisfy { paragraph in
            hasHeadingStyle(mutable, range: paragraph, fontSize: fontSize)
        }

        let originalStart = paragraphs.first!.location

        for paragraph in paragraphs.reversed() {
            let currentNsString = mutable.string as NSString
            let currentParagraph = currentNsString.paragraphRange(for: NSRange(location: paragraph.location, length: 0))

            if let marker = listMarker(in: currentParagraph, in: currentNsString) {
                mutable.replaceCharacters(in: marker.range, with: "")
                applyPlainParagraphStyle(at: currentParagraph.location, in: mutable)
                let nextLocation = currentParagraph.location + max(0, currentParagraph.length - marker.range.length)
                if marker.isOrdered {
                    _ = renumberOrderedList(startingAt: nextLocation, in: mutable, caretLocation: currentParagraph.location)
                }
            }

            let updatedNsString = mutable.string as NSString
            let updatedParagraph = updatedNsString.paragraphRange(for: NSRange(location: currentParagraph.location, length: 0))
            let paragraphText = updatedNsString.substring(with: updatedParagraph)
            let blockquoteMarkerLength = (FolioRichTextFormat.blockquoteMarker as NSString).length
            let currentParagraphStyle = mutable.attribute(
                .paragraphStyle,
                at: updatedParagraph.location,
                effectiveRange: nil
            ) as? NSParagraphStyle
            if paragraphText.hasPrefix(FolioRichTextFormat.blockquoteMarker),
               currentParagraphStyle?.headIndent == FolioRichTextFormat.blockquoteIndent {
                let markerRange = NSRange(location: updatedParagraph.location, length: blockquoteMarkerLength)
                mutable.replaceCharacters(in: markerRange, with: "")
                applyPlainParagraphStyle(at: updatedParagraph.location, in: mutable)
                let adjustedRange = NSRange(location: updatedParagraph.location, length: max(0, updatedParagraph.length - blockquoteMarkerLength))
                mutable.addAttribute(.foregroundColor, value: UIColor(Color.folioInk), range: adjustedRange)
            }

            let finalNsString = mutable.string as NSString
            let finalParagraph = finalNsString.paragraphRange(for: NSRange(location: currentParagraph.location, length: 0))
            if finalParagraph.length > 0 {
                let newFont = allMatch
                    ? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
                    : UIFont.systemFont(
                        ofSize: fontSize,
                        weight: FolioRichTextFormat.headingFontWeight(for: fontSize)
                    )
                mutable.addAttribute(.font, value: newFont, range: finalParagraph)
            }
        }

        let lastSelectedParagraph = paragraphs.last!
        let finalNsString = mutable.string as NSString
        let finalLastParagraph = finalNsString.paragraphRange(for: NSRange(location: lastSelectedParagraph.location, length: 0))
        let newRange = NSRange(location: originalStart, length: max(0, NSMaxRange(finalLastParagraph) - originalStart))
        return Result(
            attributedText: mutable,
            selectedRange: clampedSelection(newRange, to: mutable.length),
            typingAttributes: clampedSelectedRange.length == 0
                ? typingAttributes(at: clampedSelectedRange.location, in: mutable)
                : nil
        )
    }

    func splitParagraphAfterHeading(
        in attributedText: NSAttributedString,
        at location: Int
    ) -> Result? {
        guard location >= 0, location <= attributedText.length else { return nil }
        let paragraph = paragraphRange(at: location, in: attributedText)
        guard paragraph.length > 0,
               headingLevel(for: attributedText.attribute(.font, at: paragraph.location, effectiveRange: nil) as? UIFont) != nil else {
            return nil
        }
        let string = attributedText.string as NSString
        let hasTrailingNewline = string.character(at: NSMaxRange(paragraph) - 1) == 10
        let headingEnd = NSMaxRange(paragraph) - (hasTrailingNewline ? 1 : 0)
        guard location == headingEnd else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let bodyFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        mutable.insert(NSAttributedString(string: "\n", attributes: [.font: bodyFont]), at: location)
        let newParagraph = paragraphRange(at: location + 1, in: mutable)
        if newParagraph.length > 0 {
            mutable.addAttribute(.font, value: bodyFont, range: newParagraph)
            mutable.removeAttribute(FolioRichTextFormat.inlineBoldAttribute, range: newParagraph)
        }

        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: location + 1, length: 0),
            typingAttributes: [.font: bodyFont]
        )
    }

    func applyingHeadingInlineBoldToggle(
        removingTrait: Bool,
        to attributes: [NSAttributedString.Key: Any],
        in attributedText: NSAttributedString,
        at location: Int
    ) -> Result {
        var updatedAttributes = attributes
        updatedAttributes[FolioRichTextFormat.inlineBoldAttribute] = removingTrait ? nil : true
        if let font = attributes[.font] as? UIFont {
            let headingFont = UIFont.systemFont(
                ofSize: font.pointSize,
                weight: removingTrait
                    ? FolioRichTextFormat.headingFontWeight(for: font.pointSize)
                    : FolioRichTextFormat.inlineBoldFontWeight
            )
            updatedAttributes[.font] = fontBySetting(
                .traitItalic,
                enabled: font.fontDescriptor.symbolicTraits.contains(.traitItalic),
                in: headingFont
            )
        }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        if attributedText.length > 0 {
            applyHeadingInlineBoldToParagraph(removingTrait: removingTrait, in: mutable, at: location)
        }
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: location, length: 0),
            typingAttributes: updatedAttributes
        )
    }

    func headingLevel(in attributedText: NSAttributedString, paragraphs: [NSRange]) -> Int? {
        guard !paragraphs.isEmpty else { return nil }
        let levels = paragraphs.map { paragraph in
            headingLevel(for: attributedText.attribute(.font, at: paragraph.location, effectiveRange: nil) as? UIFont)
        }
        guard let first = levels.first, first != nil, levels.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    func headingLevel(for font: UIFont?) -> Int? {
        guard let font, isHeadingFont(font) else { return nil }
        switch font.pointSize {
        case let size where abs(size - FolioRichTextFormat.heading1FontSize) < 0.5: return 1
        case let size where abs(size - FolioRichTextFormat.heading2FontSize) < 0.5: return 2
        case let size where abs(size - FolioRichTextFormat.heading3FontSize) < 0.5: return 3
        default: return nil
        }
    }

    func isHeadingFont(_ font: UIFont) -> Bool {
        let expectedWeight = FolioRichTextFormat.headingFontWeight(for: font.pointSize).rawValue
        let traits = font.fontDescriptor.fontAttributes[.traits] as? [UIFontDescriptor.TraitKey: Any]
        let weight = (traits?[.weight] as? NSNumber).map { CGFloat(truncating: $0) }
        let expectedFont = UIFont.systemFont(
            ofSize: font.pointSize,
            weight: FolioRichTextFormat.headingFontWeight(for: font.pointSize)
        )
        let matchesConfiguredWeight = weight == expectedWeight
            || font.fontDescriptor.postscriptName == expectedFont.fontDescriptor.postscriptName
        let matchesItalicHeadingFont: Bool = {
            guard font.fontDescriptor.symbolicTraits.contains(.traitItalic) else { return false }
            var expectedTraits = expectedFont.fontDescriptor.symbolicTraits
            expectedTraits.insert(.traitItalic)
            guard let italicDescriptor = expectedFont.fontDescriptor.withSymbolicTraits(expectedTraits) else {
                return false
            }
            return font.fontDescriptor.postscriptName == italicDescriptor.postscriptName
        }()
        return matchesConfiguredWeight
            || matchesItalicHeadingFont
            || font.fontDescriptor.symbolicTraits.contains(.traitBold)
    }

    func isHeadingRange(_ range: NSRange, in attributedText: NSAttributedString) -> Bool {
        let paragraphs = paragraphRanges(in: range, string: attributedText.string as NSString)
        return headingLevel(in: attributedText, paragraphs: paragraphs) != nil
    }

    private func applyHeadingInlineBoldToParagraph(
        removingTrait: Bool,
        in mutable: NSMutableAttributedString,
        at location: Int
    ) {
        let paragraph = paragraphRange(at: location, in: mutable)
        let contentLength = paragraph.length > 0
            && (mutable.string as NSString).character(at: NSMaxRange(paragraph) - 1) == 10
            ? paragraph.length - 1
            : paragraph.length
        let contentRange = NSRange(location: paragraph.location, length: max(0, contentLength))
        guard contentRange.length > 0 else { return }
        mutable.enumerateAttribute(.font, in: contentRange, options: []) { value, attrRange, _ in
            let runFont = value as? UIFont ?? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
            let weight: UIFont.Weight = removingTrait
                ? FolioRichTextFormat.headingFontWeight(for: runFont.pointSize)
                : FolioRichTextFormat.inlineBoldFontWeight
            let headingFont = UIFont.systemFont(ofSize: runFont.pointSize, weight: weight)
            mutable.addAttribute(
                .font,
                value: fontBySetting(
                    .traitItalic,
                    enabled: runFont.fontDescriptor.symbolicTraits.contains(.traitItalic),
                    in: headingFont
                ),
                range: attrRange
            )
        }
        if removingTrait {
            mutable.removeAttribute(FolioRichTextFormat.inlineBoldAttribute, range: contentRange)
        } else {
            mutable.addAttribute(FolioRichTextFormat.inlineBoldAttribute, value: true, range: contentRange)
        }
    }

    private func hasHeadingStyle(_ text: NSAttributedString, range: NSRange, fontSize: CGFloat) -> Bool {
        guard range.length > 0 else { return false }
        guard let font = text.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont else { return false }
        let isSameSize = abs(font.pointSize - fontSize) < 0.5
        return isHeadingFont(font) && isSameSize
    }

    private func headingTypingResult(
        fontSize: CGFloat,
        attributedText: NSAttributedString,
        selectedRange: NSRange,
        currentTypingAttributes: [NSAttributedString.Key: Any]
    ) -> Result {
        var attributes = currentTypingAttributes
        let currentFont = attributes[.font] as? UIFont
            ?? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        let headingFont = UIFont.systemFont(
            ofSize: fontSize,
            weight: FolioRichTextFormat.headingFontWeight(for: fontSize)
        )
        attributes[.font] = headingLevel(for: currentFont) == headingLevel(for: headingFont)
            ? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
            : headingFont
        return Result(
            attributedText: attributedText,
            selectedRange: selectedRange,
            typingAttributes: attributes
        )
    }
}
