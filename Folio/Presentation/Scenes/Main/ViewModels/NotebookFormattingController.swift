import SwiftUI
import UIKit

@MainActor
final class NotebookFormattingController {
    struct Result {
        let attributedText: NSAttributedString
        let selectedRange: NSRange?
        let typingAttributes: [NSAttributedString.Key: Any]?
    }

    struct ActiveFormats {
        let isBold: Bool
        let isItalic: Bool
        let isUnorderedList: Bool
        let isOrderedList: Bool
        let hasLink: Bool
    }

    func toggleTrait(
        _ trait: UIFontDescriptor.SymbolicTraits,
        in attributedText: NSAttributedString,
        selectedRange: NSRange,
        currentTypingAttributes: [NSAttributedString.Key: Any]? = nil,
        appliesToTypingAttributes: Bool = false
    ) -> Result? {
        if selectedRange.length == 0, appliesToTypingAttributes {
            var attributes = currentTypingAttributes ?? typingAttributes(at: selectedRange.location, in: attributedText)
            let font = attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
            attributes[.font] = fontByToggling(trait, in: font)
            return Result(
                attributedText: attributedText,
                selectedRange: selectedRange,
                typingAttributes: attributes
            )
        }

        let range = selectedRange.length > 0 ? selectedRange : wordRange(at: selectedRange.location, in: attributedText)
        guard range.location != NSNotFound, range.length > 0 else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let removesTrait = hasTrait(trait, in: attributedText, range: range)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            let font = value as? UIFont ?? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
            mutable.addAttribute(.font, value: fontBySetting(trait, enabled: !removesTrait, in: font), range: attrRange)
        }

        return Result(attributedText: mutable, selectedRange: selectedRange, typingAttributes: nil)
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

        return Result(attributedText: mutable, selectedRange: nil, typingAttributes: nil)
    }

    func applyListStyle(
        ordered: Bool,
        in attributedText: NSAttributedString,
        selectedRange: NSRange
    ) -> Result? {
        if attributedText.length == 0 {
            let prefix = ordered ? "1.\t" : FolioRichTextFormat.bulletMarker
            let mutable = NSMutableAttributedString(string: prefix)
            let markerRange = NSRange(location: 0, length: (prefix as NSString).length)
            mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize), range: markerRange)
            applyListParagraphStyle(at: 0, in: mutable)
            return Result(
                attributedText: mutable,
                selectedRange: NSRange(location: markerRange.length, length: 0),
                typingAttributes: nil
            )
        }

        let selectionRange = selectedRange.length > 0 ? selectedRange : paragraphRange(at: selectedRange.location, in: attributedText)
        guard selectionRange.location != NSNotFound else { return nil }

        if selectionRange.length == 0,
           selectedRange.length == 0,
           selectedRange.location == attributedText.length,
           attributedText.string.hasSuffix("\n") {
            let prefix = ordered ? "1.\t" : FolioRichTextFormat.bulletMarker
            let mutable = NSMutableAttributedString(attributedString: attributedText)
            mutable.replaceCharacters(in: NSRange(location: selectedRange.location, length: 0), with: prefix)
            let markerRange = NSRange(
                location: selectedRange.location,
                length: (prefix as NSString).length
            )
            mutable.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize),
                range: markerRange
            )
            applyListParagraphStyle(at: selectedRange.location, in: mutable)
            return Result(
                attributedText: mutable,
                selectedRange: NSRange(location: NSMaxRange(markerRange), length: 0),
                typingAttributes: nil
            )
        }

        guard selectionRange.length > 0 else { return nil }

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

        guard replacementText.isEmpty else { return nil }
        return removeListMarker(in: attributedText, editRange: selectedRange)
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

        return Result(attributedText: mutable, selectedRange: nil, typingAttributes: nil)
    }

    func applyLink(_ url: URL, in attributedText: NSAttributedString, selectedRange: NSRange) -> Result? {
        guard FolioRichTextEditor.isSupportedLinkURL(url),
              selectedRange.length > 0,
              NSMaxRange(selectedRange) <= attributedText.length else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.addAttribute(.link, value: url, range: selectedRange)
        return Result(attributedText: mutable, selectedRange: selectedRange, typingAttributes: nil)
    }

    func activeFormats(
        in attributedText: NSAttributedString,
        selectedRange: NSRange,
        typingAttributes: [NSAttributedString.Key: Any] = [:]
    ) -> ActiveFormats {
        let usesTypingAttributes = selectedRange.length == 0 && !typingAttributes.isEmpty
        let typingFont = typingAttributes[.font] as? UIFont
        guard let textRange = effectiveTextRange(in: attributedText, selectedRange: selectedRange) else {
            return ActiveFormats(
                isBold: typingFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false,
                isItalic: typingFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false,
                isUnorderedList: false,
                isOrderedList: false,
                hasLink: typingAttributes[.link] != nil
            )
        }

        let listRange = selectedRange.length > 0 ? selectedRange : textRange
        let paragraphs = paragraphRanges(in: listRange, string: attributedText.string as NSString)
        let listMarkers = paragraphs.compactMap { listMarker(in: $0, in: attributedText.string as NSString) }
        return ActiveFormats(
            isBold: usesTypingAttributes
                ? typingFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
                : hasTrait(.traitBold, in: attributedText, range: textRange),
            isItalic: usesTypingAttributes
                ? typingFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
                : hasTrait(.traitItalic, in: attributedText, range: textRange),
            isUnorderedList: !paragraphs.isEmpty && listMarkers.count == paragraphs.count && listMarkers.allSatisfy { !$0.isOrdered },
            isOrderedList: !paragraphs.isEmpty && listMarkers.count == paragraphs.count && listMarkers.allSatisfy(\.isOrdered),
            hasLink: usesTypingAttributes ? typingAttributes[.link] != nil : hasLink(in: attributedText, range: textRange)
        )
    }

    private func hasHeadingStyle(_ text: NSAttributedString, range: NSRange, fontSize: CGFloat) -> Bool {
        guard range.length > 0 else { return false }
        guard let font = text.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont else { return false }
        let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
        let isSameSize = abs(font.pointSize - fontSize) < 0.5
        return isBold && isSameSize
    }

    private func typingAttributes(at location: Int, in attributedText: NSAttributedString) -> [NSAttributedString.Key: Any] {
        guard attributedText.length > 0 else {
            return [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        }
        let index = min(max(location - 1, 0), attributedText.length - 1)
        return attributedText.attributes(at: index, effectiveRange: nil)
    }

    private func hasTrait(
        _ trait: UIFontDescriptor.SymbolicTraits,
        in attributedText: NSAttributedString,
        range: NSRange
    ) -> Bool {
        var foundFont = false
        var hasTrait = true
        attributedText.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
            guard let font = value as? UIFont else {
                hasTrait = false
                stop.pointee = true
                return
            }
            foundFont = true
            if !font.fontDescriptor.symbolicTraits.contains(trait) {
                hasTrait = false
                stop.pointee = true
            }
        }
        return foundFont && hasTrait
    }

    private func hasLink(in attributedText: NSAttributedString, range: NSRange) -> Bool {
        var hasLink = true
        attributedText.enumerateAttribute(.link, in: range, options: []) { value, _, stop in
            if value == nil {
                hasLink = false
                stop.pointee = true
            }
        }
        return hasLink
    }

    private func effectiveTextRange(in attributedText: NSAttributedString, selectedRange: NSRange) -> NSRange? {
        guard attributedText.length > 0 else { return nil }
        if selectedRange.length > 0, NSMaxRange(selectedRange) <= attributedText.length {
            return selectedRange
        }
        let location = min(max(selectedRange.location - 1, 0), attributedText.length - 1)
        return NSRange(location: location, length: 1)
    }

    private func fontByToggling(_ trait: UIFontDescriptor.SymbolicTraits, in font: UIFont) -> UIFont {
        fontBySetting(trait, enabled: !font.fontDescriptor.symbolicTraits.contains(trait), in: font)
    }

    private func fontBySetting(_ trait: UIFontDescriptor.SymbolicTraits, enabled: Bool, in font: UIFont) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        if enabled {
            traits.insert(trait)
        } else {
            traits.remove(trait)
        }
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
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

    private func applyListParagraphStyle(at location: Int, in mutable: NSMutableAttributedString) {
        guard mutable.length > 0, location < mutable.length else { return }
        let paragraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.listIndent
        style.firstLineHeadIndent = 0
        mutable.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }

    private func applyPlainParagraphStyle(at location: Int, in mutable: NSMutableAttributedString) {
        guard mutable.length > 0, location < mutable.length else { return }
        let paragraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let style = NSMutableParagraphStyle()
        style.headIndent = 0
        style.firstLineHeadIndent = 0
        mutable.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }

    private func renumberOrderedList(containing location: Int, in mutable: NSMutableAttributedString, caretLocation: Int) -> Int {
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

    private func renumberOrderedList(startingAt location: Int, in mutable: NSMutableAttributedString, caretLocation: Int) -> Int {
        let paragraphs = allParagraphRanges(in: mutable.string as NSString)
        guard let index = paragraphs.firstIndex(where: { NSLocationInRange(location, $0) }),
              listMarker(in: paragraphs[index], in: mutable.string as NSString)?.isOrdered == true else { return caretLocation }

        var end = index
        while end + 1 < paragraphs.count, listMarker(in: paragraphs[end + 1], in: mutable.string as NSString)?.isOrdered == true {
            end += 1
        }
        return renumberOrderedList(paragraphs: Array(paragraphs[index...end]), in: mutable, caretLocation: caretLocation)
    }

    private func renumberOrderedList(paragraphs: [NSRange], in mutable: NSMutableAttributedString, caretLocation: Int) -> Int {
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

    private func allParagraphRanges(in string: NSString) -> [NSRange] {
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

    private func applyListMarkers(to paragraphs: [NSRange], ordered: Bool, in mutable: NSMutableAttributedString) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = FolioRichTextFormat.listIndent
        paragraphStyle.firstLineHeadIndent = 0

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
