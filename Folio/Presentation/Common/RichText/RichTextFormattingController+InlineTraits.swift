import UIKit

@MainActor
extension RichTextFormattingController {
    func toggleTrait(
        _ trait: UIFontDescriptor.SymbolicTraits,
        in attributedText: NSAttributedString,
        selectedRange: NSRange,
        currentTypingAttributes: [NSAttributedString.Key: Any]? = nil,
        appliesToTypingAttributes: Bool = false
    ) -> Result? {
        let clampedSelectedRange = clampedSelection(selectedRange, to: attributedText.length)
        if clampedSelectedRange.length == 0, appliesToTypingAttributes {
            return toggleTraitOnTypingAttributes(
                trait,
                in: attributedText,
                at: clampedSelectedRange.location,
                currentTypingAttributes: currentTypingAttributes,
                selectedRange: clampedSelectedRange
            )
        }

        let range = clampedSelectedRange.length > 0
            ? clampedSelectedRange
            : wordRange(at: clampedSelectedRange.location, in: attributedText)
        guard range.location != NSNotFound, range.length > 0 else { return nil }
        return toggleTraitOnRange(trait, in: attributedText, range: range, selectedRange: clampedSelectedRange)
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
                isBold: isInlineBold(in: typingAttributes)
                    || (headingLevel(for: typingFont) == nil
                        && typingFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true),
                isItalic: typingFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false,
                isHeading1: headingLevel(for: typingFont) == 1,
                isHeading2: headingLevel(for: typingFont) == 2,
                isHeading3: headingLevel(for: typingFont) == 3,
                isUnorderedList: false,
                isOrderedList: false,
                hasLink: typingAttributes[.link] != nil,
                isBlockquote: false
            )
        }

        let listRange = selectedRange.length > 0 ? selectedRange : textRange
        let paragraphs = paragraphRanges(in: listRange, string: attributedText.string as NSString)
        let listMarkers = paragraphs.compactMap { listMarker(in: $0, in: attributedText.string as NSString) }
        let selectedHeading = headingLevel(in: attributedText, paragraphs: paragraphs)
        let activeHeading = usesTypingAttributes ? headingLevel(for: typingFont) : selectedHeading
        let isQuotedSelection = !paragraphs.isEmpty && paragraphs.allSatisfy { isBlockquote($0, in: attributedText) }
        let inlineBoldAtCursor = usesTypingAttributes
            && activeHeading != nil
            && isInlineBold(at: selectedRange.location, in: attributedText)
        return ActiveFormats(
            isBold: usesTypingAttributes
                ? (isInlineBold(in: typingAttributes)
                    || inlineBoldAtCursor
                    || (activeHeading == nil && typingFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true))
                : (activeHeading == nil
                    ? hasTrait(.traitBold, in: attributedText, range: textRange)
                    : hasInlineBold(in: attributedText, range: textRange)),
            isItalic: usesTypingAttributes
                ? typingFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
                : hasTrait(.traitItalic, in: attributedText, range: textRange),
            isHeading1: activeHeading == 1,
            isHeading2: activeHeading == 2,
            isHeading3: activeHeading == 3,
            isUnorderedList: !paragraphs.isEmpty && listMarkers.count == paragraphs.count && listMarkers.allSatisfy { !$0.isOrdered },
            isOrderedList: !paragraphs.isEmpty && listMarkers.count == paragraphs.count && listMarkers.allSatisfy(\.isOrdered),
            hasLink: usesTypingAttributes ? typingAttributes[.link] != nil : hasLink(in: attributedText, range: textRange),
            isBlockquote: isQuotedSelection
        )
    }

    private func toggleTraitOnTypingAttributes(
        _ trait: UIFontDescriptor.SymbolicTraits,
        in attributedText: NSAttributedString,
        at location: Int,
        currentTypingAttributes: [NSAttributedString.Key: Any]?,
        selectedRange: NSRange
    ) -> Result {
        var attributes = currentTypingAttributes ?? typingAttributes(at: location, in: attributedText)
        let font = attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        if trait == .traitBold {
            let isInlineBold = attributes[FolioRichTextFormat.inlineBoldAttribute] as? Bool == true
            let isHeading = headingLevel(for: font) != nil
            let removesTrait = isHeading ? isInlineBold : font.fontDescriptor.symbolicTraits.contains(.traitBold)
            if isHeading {
                let updated = applyingHeadingInlineBoldToggle(
                    removingTrait: removesTrait,
                    to: attributes,
                    in: attributedText,
                    at: location
                )
                return Result(
                    attributedText: updated.attributedText,
                    selectedRange: selectedRange,
                    typingAttributes: updated.typingAttributes
                )
            }
            attributes[.font] = fontBySetting(trait, enabled: !removesTrait, in: font)
            attributes[FolioRichTextFormat.inlineBoldAttribute] = removesTrait ? nil : true
        } else {
            attributes[.font] = fontByToggling(trait, in: font)
        }
        return Result(
            attributedText: attributedText,
            selectedRange: selectedRange,
            typingAttributes: attributes
        )
    }

    private func toggleTraitOnRange(
        _ trait: UIFontDescriptor.SymbolicTraits,
        in attributedText: NSAttributedString,
        range: NSRange,
        selectedRange: NSRange
    ) -> Result? {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let isHeading = trait == .traitBold && isHeadingRange(range, in: attributedText)
        let removesTrait = isHeading
            ? hasInlineBold(in: attributedText, range: range)
            : hasTrait(trait, in: attributedText, range: range)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            let font = value as? UIFont ?? UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
            if trait == .traitBold && isHeading {
                let weight: UIFont.Weight = removesTrait
                    ? FolioRichTextFormat.headingFontWeight(for: font.pointSize)
                    : FolioRichTextFormat.inlineBoldFontWeight
                let headingFont = UIFont.systemFont(ofSize: font.pointSize, weight: weight)
                mutable.addAttribute(
                    .font,
                    value: fontBySetting(
                        .traitItalic,
                        enabled: font.fontDescriptor.symbolicTraits.contains(.traitItalic),
                        in: headingFont
                    ),
                    range: attrRange
                )
            } else {
                mutable.addAttribute(.font, value: fontBySetting(trait, enabled: !removesTrait, in: font), range: attrRange)
            }
        }
        if trait == .traitBold {
            if removesTrait {
                mutable.removeAttribute(FolioRichTextFormat.inlineBoldAttribute, range: range)
            } else {
                mutable.addAttribute(FolioRichTextFormat.inlineBoldAttribute, value: true, range: range)
            }
        }
        return Result(attributedText: mutable, selectedRange: selectedRange, typingAttributes: nil)
    }

    private func isInlineBold(in attributes: [NSAttributedString.Key: Any]) -> Bool {
        attributes[FolioRichTextFormat.inlineBoldAttribute] as? Bool == true
    }

    private func isInlineBold(at location: Int, in attributedText: NSAttributedString) -> Bool {
        guard attributedText.length > 0 else { return false }
        let index = min(max(location, 0), attributedText.length - 1)
        return attributedText.attribute(
            FolioRichTextFormat.inlineBoldAttribute,
            at: index,
            effectiveRange: nil
        ) as? Bool == true
    }

    private func hasInlineBold(in attributedText: NSAttributedString, range: NSRange) -> Bool {
        var foundBold = false
        var allBold = true
        attributedText.enumerateAttribute(FolioRichTextFormat.inlineBoldAttribute, in: range, options: []) { value, _, stop in
            foundBold = true
            if value as? Bool != true {
                allBold = false
                stop.pointee = true
            }
        }
        return foundBold && allBold
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
        let location = min(max(selectedRange.location, 0), attributedText.length - 1)
        return NSRange(location: location, length: 1)
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

    private func fontByToggling(_ trait: UIFontDescriptor.SymbolicTraits, in font: UIFont) -> UIFont {
        fontBySetting(trait, enabled: !font.fontDescriptor.symbolicTraits.contains(trait), in: font)
    }

    func fontBySetting(_ trait: UIFontDescriptor.SymbolicTraits, enabled: Bool, in font: UIFont) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        if enabled {
            traits.insert(trait)
        } else {
            traits.remove(trait)
        }
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
