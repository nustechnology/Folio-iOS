import SwiftUI
import UIKit

@MainActor
final class NotebookFormattingController {
    struct Result {
        let attributedText: NSAttributedString
        let selectedRange: NSRange?
    }

    func toggleTrait(
        _ trait: UIFontDescriptor.SymbolicTraits,
        in attributedText: NSAttributedString,
        selectedRange: NSRange
    ) -> Result? {
        let range = selectedRange.length > 0 ? selectedRange : wordRange(at: selectedRange.location, in: attributedText)
        guard range.location != NSNotFound, range.length > 0 else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let font = value as? UIFont else { return }
            let currentTraits = font.fontDescriptor.symbolicTraits
            let newFont: UIFont
            if currentTraits.contains(trait) {
                let remaining = currentTraits.subtracting(trait)
                if let descriptor = font.fontDescriptor.withSymbolicTraits(remaining) {
                    newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                } else {
                    newFont = UIFont.systemFont(ofSize: font.pointSize)
                }
            } else {
                if let descriptor = font.fontDescriptor.withSymbolicTraits(currentTraits.union(trait)) {
                    newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                } else {
                    newFont = font
                }
            }
            mutable.addAttribute(.font, value: newFont, range: attrRange)
        }

        return Result(attributedText: mutable, selectedRange: nil)
    }

    func applyHeading(
        fontSize: CGFloat,
        in attributedText: NSAttributedString,
        selectedRange: NSRange
    ) -> Result? {
        let range = selectedRange.length > 0 ? selectedRange : paragraphRange(at: selectedRange.location, in: attributedText)
        guard range.location != NSNotFound, range.length > 0 else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let isCurrentlyHeading = hasHeadingStyle(mutable, range: range, fontSize: fontSize)

        if isCurrentlyHeading {
            let bodyFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
            mutable.addAttribute(.font, value: bodyFont, range: range)
        } else {
            let headingFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            mutable.addAttribute(.font, value: headingFont, range: range)
        }

        return Result(attributedText: mutable, selectedRange: nil)
    }

    func applyListStyle(
        ordered: Bool,
        in attributedText: NSAttributedString,
        selectedRange: NSRange
    ) -> Result? {
        let selectionRange = selectedRange.length > 0 ? selectedRange : paragraphRange(at: selectedRange.location, in: attributedText)
        guard selectionRange.location != NSNotFound, selectionRange.length > 0 else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let nsString = mutable.string as NSString
        let paragraphs = paragraphRanges(in: selectionRange, string: nsString)
        guard !paragraphs.isEmpty else { return nil }

        let allMatch = paragraphs.allSatisfy { paragraph in
            guard let marker = listMarker(in: paragraph, in: nsString) else { return false }
            return marker.isOrdered == ordered
        }

        let originalLength = mutable.length
        let originalStart = paragraphs.first!.location
        let originalAffectedLength = NSMaxRange(paragraphs.last!) - originalStart

        if allMatch {
            removeListMarkers(from: paragraphs, in: mutable)
        } else {
            applyListMarkers(to: paragraphs, ordered: ordered, in: mutable)
        }

        let delta = mutable.length - originalLength
        let newRange = NSRange(location: originalStart, length: originalAffectedLength + delta)
        return Result(attributedText: mutable, selectedRange: newRange)
    }

    func applyBlockquote(in attributedText: NSAttributedString, selectedRange: NSRange) -> Result? {
        let range = paragraphRange(at: selectedRange.location, in: attributedText)
        guard range.location != NSNotFound, range.length > 0 else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let paragraphText = (mutable.string as NSString).substring(with: range)
        let markerLength = (FolioRichTextFormat.blockquoteMarker as NSString).length
        let isBlockquote = paragraphText.hasPrefix(FolioRichTextFormat.blockquoteMarker)

        if isBlockquote {
            let markerRange = NSRange(location: range.location, length: markerLength)
            mutable.replaceCharacters(in: markerRange, with: "")
            let adjustedRange = NSRange(location: range.location, length: range.length - markerLength)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 0
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: adjustedRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(Color.folioInk), range: adjustedRange)
        } else {
            let prefix = FolioRichTextFormat.blockquoteMarker
            mutable.replaceCharacters(in: NSRange(location: range.location, length: 0), with: prefix)
            let adjustedRange = NSRange(location: range.location, length: range.length + markerLength)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
            paragraphStyle.headIndent = FolioRichTextFormat.blockquoteIndent
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: adjustedRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(Color.folioInkMuted), range: adjustedRange)
        }

        return Result(attributedText: mutable, selectedRange: nil)
    }

    private func hasHeadingStyle(_ text: NSAttributedString, range: NSRange, fontSize: CGFloat) -> Bool {
        guard range.length > 0 else { return false }
        guard let font = text.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont else { return false }
        let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
        let isSameSize = abs(font.pointSize - fontSize) < 0.5
        return isBold && isSameSize
    }

    private func wordRange(at location: Int, in attributedText: NSAttributedString) -> NSRange {
        let string = attributedText.string as NSString
        if string.length == 0 { return NSRange(location: 0, length: 0) }
        let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
        var wordRange = NSRange(location: NSNotFound, length: 0)
        string.enumerateSubstrings(
            in: paragraphRange,
            options: [.byWords]
        ) { _, substringRange, _, _ in
            if NSLocationInRange(location, substringRange) || location == substringRange.location {
                wordRange = substringRange
            }
        }
        return wordRange.length > 0 ? wordRange : NSRange(location: NSNotFound, length: 0)
    }

    private func paragraphRange(at location: Int, in attributedText: NSAttributedString) -> NSRange {
        let string = attributedText.string as NSString
        return string.paragraphRange(for: NSRange(location: location, length: 0))
    }

    private func paragraphRanges(in range: NSRange, string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = range.location
        while location < NSMaxRange(range) {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            ranges.append(paragraphRange)
            let next = NSMaxRange(paragraphRange)
            if next <= location { break }
            location = next
        }
        return ranges
    }

    private struct ListMarker {
        let range: NSRange
        let isOrdered: Bool
    }

    private func listMarker(in paragraphRange: NSRange, in string: NSString) -> ListMarker? {
        let text = string.substring(with: paragraphRange)
        if text.hasPrefix(FolioRichTextFormat.bulletMarker) {
            let length = (FolioRichTextFormat.bulletMarker as NSString).length
            return ListMarker(range: NSRange(location: paragraphRange.location, length: length), isOrdered: false)
        }
        if let length = FolioRichTextFormat.orderedListMarkerLength(in: text) {
            return ListMarker(range: NSRange(location: paragraphRange.location, length: length), isOrdered: true)
        }
        return nil
    }

    private func applyListMarkers(to paragraphs: [NSRange], ordered: Bool, in mutable: NSMutableAttributedString) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = FolioRichTextFormat.listIndent
        paragraphStyle.firstLineHeadIndent = FolioRichTextFormat.listIndent

        for (index, paragraph) in paragraphs.enumerated().reversed() {
            let nsString = mutable.string as NSString
            if let existing = listMarker(in: paragraph, in: nsString) {
                mutable.replaceCharacters(in: existing.range, with: "")
            }
            let prefix = ordered ? "\(index + 1).\t" : FolioRichTextFormat.bulletMarker
            mutable.replaceCharacters(in: NSRange(location: paragraph.location, length: 0), with: prefix)
            let markerRange = NSRange(location: paragraph.location, length: (prefix as NSString).length)
            mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize), range: markerRange)
            let currentParagraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: paragraph.location, length: 0))
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: currentParagraph)
        }
    }

    private func removeListMarkers(from paragraphs: [NSRange], in mutable: NSMutableAttributedString) {
        let plainStyle = NSMutableParagraphStyle()
        plainStyle.headIndent = 0
        plainStyle.firstLineHeadIndent = 0

        for paragraph in paragraphs.reversed() {
            let nsString = mutable.string as NSString
            if let marker = listMarker(in: paragraph, in: nsString) {
                mutable.replaceCharacters(in: marker.range, with: "")
            }
            let currentParagraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: paragraph.location, length: 0))
            mutable.addAttribute(.paragraphStyle, value: plainStyle, range: currentParagraph)
        }
    }
}
