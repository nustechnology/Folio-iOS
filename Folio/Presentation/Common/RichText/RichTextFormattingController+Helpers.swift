import UIKit

@MainActor
extension RichTextFormattingController {
    func typingAttributes(
        at location: Int,
        in attributedText: NSAttributedString
    ) -> [NSAttributedString.Key: Any] {
        guard attributedText.length > 0 else {
            return [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        }
        let index = min(max(location - 1, 0), attributedText.length - 1)
        return attributedText.attributes(at: index, effectiveRange: nil)
    }

    func paragraphRange(at location: Int, in attributedText: NSAttributedString) -> NSRange {
        let string = attributedText.string as NSString
        return string.paragraphRange(for: NSRange(location: location, length: 0))
    }

    func paragraphRanges(in range: NSRange, string: NSString) -> [NSRange] {
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

    func clampedSelection(_ selection: NSRange, to textLength: Int) -> NSRange {
        let location = min(max(selection.location, 0), textLength)
        let length = min(max(selection.length, 0), textLength - location)
        return NSRange(location: location, length: length)
    }

    func applyPlainParagraphStyle(at location: Int, in mutable: NSMutableAttributedString) {
        guard mutable.length > 0, location < mutable.length else { return }
        let paragraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let style = NSMutableParagraphStyle()
        style.headIndent = 0
        style.firstLineHeadIndent = 0
        mutable.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }
}
