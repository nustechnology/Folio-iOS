import UIKit

@MainActor
extension RichTextFormattingController {
    struct ListMarker {
        let range: NSRange
        let isOrdered: Bool
    }

    func applyListStyle(
        ordered: Bool,
        in attributedText: NSAttributedString,
        selectedRange: NSRange
    ) -> Result? {
        if attributedText.length == 0 {
            return applyListStyleToEmpty(ordered: ordered, in: attributedText)
        }

        let selectionRange = selectedRange.length > 0
            ? selectedRange
            : paragraphRange(at: selectedRange.location, in: attributedText)
        guard selectionRange.location != NSNotFound else { return nil }

        if selectionRange.length == 0,
           selectedRange.length == 0,
           selectedRange.location == attributedText.length,
           attributedText.string.hasSuffix("\n") {
            return applyListStyleToEnd(ordered: ordered, in: attributedText, at: selectedRange.location)
        }

        guard selectionRange.length > 0 else { return nil }
        return applyListStyle(to: selectionRange, ordered: ordered, in: attributedText)
    }

    func applyListEdit(
        replacementText: String,
        in attributedText: NSAttributedString,
        selectedRange: NSRange
    ) -> Result? {
        guard selectedRange.location >= 0,
              selectedRange.length >= 0,
              NSMaxRange(selectedRange) <= attributedText.length else { return nil }

        if replacementText == "\n", selectedRange.length == 0 {
            return insertListItem(in: attributedText, at: selectedRange.location)
        }

        if replacementText.isEmpty {
            return removeListMarker(in: attributedText, editRange: selectedRange)
        }

        return replaceListMarker(in: attributedText, editRange: selectedRange, replacementText: replacementText)
    }

    func listMarker(in paragraphRange: NSRange, in string: NSString) -> ListMarker? {
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

    private func applyListStyleToEmpty(ordered: Bool, in attributedText: NSAttributedString) -> Result? {
        let prefix = ordered ? "1.\t" : FolioRichTextFormat.bulletMarker
        let mutable = NSMutableAttributedString(string: prefix)
        let markerRange = NSRange(location: 0, length: (prefix as NSString).length)
        mutable.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize),
            range: markerRange
        )
        applyListParagraphStyle(at: 0, in: mutable)
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: markerRange.length, length: 0),
            typingAttributes: nil
        )
    }

    private func applyListStyleToEnd(ordered: Bool, in attributedText: NSAttributedString, at location: Int) -> Result? {
        let prefix = ordered ? "1.\t" : FolioRichTextFormat.bulletMarker
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.replaceCharacters(in: NSRange(location: location, length: 0), with: prefix)
        let markerRange = NSRange(location: location, length: (prefix as NSString).length)
        mutable.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize),
            range: markerRange
        )
        applyListParagraphStyle(at: location, in: mutable)
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: NSMaxRange(markerRange), length: 0),
            typingAttributes: nil
        )
    }

    private func applyListStyle(to selectionRange: NSRange, ordered: Bool, in attributedText: NSAttributedString) -> Result? {
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
        return Result(attributedText: mutable, selectedRange: newRange, typingAttributes: nil)
    }

    private func insertListItem(in attributedText: NSAttributedString, at location: Int) -> Result? {
        let string = attributedText.string as NSString
        guard string.length > 0 else { return nil }
        let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
        guard let marker = listMarker(in: paragraph, in: string) else { return nil }

        let markerEnd = NSMaxRange(marker.range)
        let paragraphEnd = paragraph.length > 0 && string.character(at: NSMaxRange(paragraph) - 1) == 10
            ? NSMaxRange(paragraph) - 1
            : NSMaxRange(paragraph)
        let isEmptyItem = markerEnd >= paragraphEnd
        let mutable = NSMutableAttributedString(attributedString: attributedText)

        if isEmptyItem {
            removeListMarkers(from: [paragraph], in: mutable)
            return Result(
                attributedText: mutable,
                selectedRange: NSRange(location: paragraph.location, length: 0),
                typingAttributes: typingAttributes(at: paragraph.location, in: mutable)
            )
        }

        let prefix = marker.isOrdered ? "0.\t" : FolioRichTextFormat.bulletMarker
        let insertion = "\n\(prefix)"
        let typingAttributes = typingAttributes(at: location, in: attributedText)
        mutable.replaceCharacters(in: NSRange(location: location, length: 0), with: insertion)
        let markerRange = NSRange(location: location + 1, length: (prefix as NSString).length)
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize), range: markerRange)
        applyListParagraphStyle(at: location + 1, in: mutable)

        var caretLocation = NSMaxRange(markerRange)
        if marker.isOrdered {
            caretLocation = renumberOrderedList(containing: location + 1, in: mutable, caretLocation: caretLocation)
        }
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: caretLocation, length: 0),
            typingAttributes: typingAttributes
        )
    }

    private func removeListMarker(in attributedText: NSAttributedString, editRange: NSRange) -> Result? {
        let string = attributedText.string as NSString
        guard string.length > 0 else { return nil }
        let paragraph = string.paragraphRange(for: NSRange(location: editRange.location, length: 0))
        guard let marker = listMarker(in: paragraph, in: string),
              editRange.length > 0,
              editRange.location >= marker.range.location,
              NSMaxRange(editRange) <= NSMaxRange(marker.range) else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.replaceCharacters(in: marker.range, with: "")
        applyPlainParagraphStyle(at: paragraph.location, in: mutable)

        let nextLocation = paragraph.location + max(0, paragraph.length - marker.range.length)
        let caretLocation = marker.isOrdered
            ? renumberOrderedList(startingAt: nextLocation, in: mutable, caretLocation: paragraph.location)
            : paragraph.location
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: caretLocation, length: 0),
            typingAttributes: typingAttributes(at: caretLocation, in: mutable)
        )
    }

    private func replaceListMarker(
        in attributedText: NSAttributedString,
        editRange: NSRange,
        replacementText: String
    ) -> Result? {
        let string = attributedText.string as NSString
        guard string.length > 0,
              editRange.length > 0 else { return nil }

        let paragraph = string.paragraphRange(for: NSRange(location: editRange.location, length: 0))
        guard let marker = listMarker(in: paragraph, in: string),
              marker.range.location >= editRange.location,
              NSMaxRange(marker.range) <= NSMaxRange(editRange) else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.replaceCharacters(in: editRange, with: replacementText)
        applyPlainParagraphStyle(at: paragraph.location, in: mutable)

        let caretLocation = paragraph.location + (replacementText as NSString).length
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: caretLocation, length: 0),
            typingAttributes: typingAttributes(at: caretLocation, in: mutable)
        )
    }

    private func applyListParagraphStyle(at location: Int, in mutable: NSMutableAttributedString) {
        guard mutable.length > 0, location < mutable.length else { return }
        let paragraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.listIndent
        style.firstLineHeadIndent = 0
        mutable.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }

    private func applyListMarkers(to paragraphs: [NSRange], ordered: Bool, in mutable: NSMutableAttributedString) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = FolioRichTextFormat.listIndent
        paragraphStyle.firstLineHeadIndent = 0
        let bodyFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)

        for (index, paragraph) in paragraphs.enumerated().reversed() {
            let nsString = mutable.string as NSString
            let currentParagraph = nsString.paragraphRange(for: NSRange(location: paragraph.location, length: 0))
            mutable.addAttribute(.font, value: bodyFont, range: currentParagraph)

            if let existing = listMarker(in: currentParagraph, in: nsString) {
                mutable.replaceCharacters(in: existing.range, with: "")
            }
            let prefix = ordered ? "\(index + 1).\t" : FolioRichTextFormat.bulletMarker
            mutable.replaceCharacters(in: NSRange(location: currentParagraph.location, length: 0), with: prefix)
            let markerRange = NSRange(location: currentParagraph.location, length: (prefix as NSString).length)
            mutable.addAttribute(.font, value: bodyFont, range: markerRange)
            let updatedParagraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: currentParagraph.location, length: 0))
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: updatedParagraph)
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

    func renumberOrderedList(containing location: Int, in mutable: NSMutableAttributedString, caretLocation: Int) -> Int {
        let paragraphs = allParagraphRanges(in: mutable.string as NSString)
        guard let index = paragraphs.firstIndex(where: { NSLocationInRange(location, $0) }),
              listMarker(in: paragraphs[index], in: mutable.string as NSString)?.isOrdered == true else { return caretLocation }

        var start = index
        while start > 0, listMarker(in: paragraphs[start - 1], in: mutable.string as NSString)?.isOrdered == true {
            start -= 1
        }
        var end = index
        while end + 1 < paragraphs.count, listMarker(in: paragraphs[end + 1], in: mutable.string as NSString)?.isOrdered == true {
            end += 1
        }
        return renumberOrderedList(paragraphs: Array(paragraphs[start...end]), in: mutable, caretLocation: caretLocation)
    }

    func renumberOrderedList(startingAt location: Int, in mutable: NSMutableAttributedString, caretLocation: Int) -> Int {
        let paragraphs = allParagraphRanges(in: mutable.string as NSString)
        guard let index = paragraphs.firstIndex(where: { NSLocationInRange(location, $0) }),
              listMarker(in: paragraphs[index], in: mutable.string as NSString)?.isOrdered == true else { return caretLocation }

        var end = index
        while end + 1 < paragraphs.count, listMarker(in: paragraphs[end + 1], in: mutable.string as NSString)?.isOrdered == true {
            end += 1
        }
        return renumberOrderedList(paragraphs: Array(paragraphs[index...end]), in: mutable, caretLocation: caretLocation)
    }

    func renumberOrderedList(paragraphs: [NSRange], in mutable: NSMutableAttributedString, caretLocation: Int) -> Int {
        var adjustedCaret = caretLocation
        for (offset, paragraph) in paragraphs.enumerated().reversed() {
            let string = mutable.string as NSString
            guard let marker = listMarker(in: paragraph, in: string) else { continue }
            let replacement = "\(offset + 1).\t"
            mutable.replaceCharacters(in: marker.range, with: replacement)
            let delta = (replacement as NSString).length - marker.range.length
            if marker.range.location < adjustedCaret { adjustedCaret += delta }
        }
        return adjustedCaret
    }

    func allParagraphRanges(in string: NSString) -> [NSRange] {
        var paragraphs: [NSRange] = []
        var location = 0
        while location < string.length {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            paragraphs.append(paragraph)
            let next = NSMaxRange(paragraph)
            if next <= location { break }
            location = next
        }
        return paragraphs
    }
}
