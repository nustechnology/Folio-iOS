import SwiftUI
import UIKit

struct FolioRichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    var typingAttributes: Binding<[NSAttributedString.Key: Any]>?
    var onTextChange: (NSAttributedString) -> Void
    var onEditingChanged: ((Bool) -> Void)?
    var textContainerTopInset: CGFloat = 16
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onBlockquoteShortcut: (() -> Void)?
    var onUnorderedListShortcut: (() -> Void)?
    var onOrderedListShortcut: (() -> Void)?
    var onUndoShortcut: (() -> Void)?
    var onRedoShortcut: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = FolioTextView()
        let coordinator = context.coordinator
        textView.canUndo = canUndo
        textView.canRedo = canRedo
        textView.onBlockquoteKeyCommand = { [weak coordinator] in
            coordinator?.parent.onBlockquoteShortcut?()
        }
        textView.onUnorderedListKeyCommand = { [weak coordinator] in
            coordinator?.parent.onUnorderedListShortcut?()
        }
        textView.onOrderedListKeyCommand = { [weak coordinator] in
            coordinator?.parent.onOrderedListShortcut?()
        }
        textView.onUndoKeyCommand = { [weak coordinator] in
            coordinator?.parent.onUndoShortcut?()
        }
        textView.onRedoKeyCommand = { [weak coordinator] in
            coordinator?.parent.onRedoShortcut?()
        }
        textView.delegate = coordinator
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textColor = UIColor(Color.folioInk)
        textView.textContainerInset = UIEdgeInsets(top: textContainerTopInset, left: 16, bottom: 96, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        textView.allowsEditingTextAttributes = false
        textView.dataDetectorTypes = []
        textView.spellCheckingType = .default
        textView.autocorrectionType = .default
        textView.tintColor = UIColor(Color.folioGold)
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true

        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isSynchronizingUIView = true
        defer { context.coordinator.isSynchronizingUIView = false }
        if let folioTextView = textView as? FolioTextView {
            folioTextView.canUndo = canUndo
            folioTextView.canRedo = canRedo
        }
        if textView.attributedText != attributedText {
            textView.attributedText = attributedText
            (textView as? FolioTextView)?.applyBlockquotePresentation()
        }
        if Self.shouldSynchronizeSelection(
            current: textView.selectedRange,
            desired: selectedRange,
            textLength: textView.textStorage.length
        ) {
            textView.selectedRange = selectedRange
        }
        if let typingAttributes, !typingAttributes.wrappedValue.isEmpty {
            textView.typingAttributes = typingAttributes.wrappedValue
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: FolioRichTextEditor
        var isSynchronizingUIView = false
        weak var textView: UITextView?

        init(parent: FolioRichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSynchronizingUIView else { return }
            (textView as? FolioTextView)?.applyBlockquotePresentation()
            parent.attributedText = textView.attributedText
            parent.selectedRange = textView.selectedRange
            parent.onTextChange(textView.attributedText)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let shouldClearLinkTypingAttribute = text == " " || text == "\n"
            let hadLinkTypingAttribute = textView.typingAttributes[.link] != nil
            if shouldClearLinkTypingAttribute {
                clearLinkTypingAttribute(in: textView)
            }

            guard let attributed = textView.attributedText else { return true }
            let markers = FolioRichTextEditor.formattingMarkerRanges(in: attributed)
            let formattingController = RichTextFormattingController()
            if let result = formattingController.applyBlockquoteEdit(
                replacementText: text,
                in: attributed,
                selectedRange: range
            ) {
                textView.attributedText = result.attributedText
                textView.selectedRange = result.selectedRange ?? NSRange(location: 0, length: 0)
                if var typingAttributes = result.typingAttributes {
                    if shouldClearLinkTypingAttribute {
                        typingAttributes.removeValue(forKey: .link)
                    }
                    textView.typingAttributes = typingAttributes
                    parent.typingAttributes?.wrappedValue = typingAttributes
                }
                parent.onTextChange(result.attributedText)
                parent.attributedText = result.attributedText
                parent.selectedRange = textView.selectedRange
                return false
            }
            if text.isEmpty,
               let result = formattingController.removeEmptyBlockquote(in: attributed, editRange: range) {
                textView.attributedText = result.attributedText
                textView.selectedRange = result.selectedRange ?? NSRange(location: 0, length: 0)
                if var typingAttributes = result.typingAttributes {
                    if shouldClearLinkTypingAttribute {
                        typingAttributes.removeValue(forKey: .link)
                    }
                    textView.typingAttributes = typingAttributes
                    parent.typingAttributes?.wrappedValue = typingAttributes
                }
                parent.onTextChange(result.attributedText)
                parent.attributedText = result.attributedText
                parent.selectedRange = textView.selectedRange
                return false
            }
            if let result = formattingController.applyListEdit(replacementText: text, in: attributed, selectedRange: range) {
                textView.attributedText = result.attributedText
                textView.selectedRange = result.selectedRange ?? NSRange(location: 0, length: 0)
                if var typingAttributes = result.typingAttributes {
                    if shouldClearLinkTypingAttribute {
                        typingAttributes.removeValue(forKey: .link)
                    }
                    textView.typingAttributes = typingAttributes
                    parent.typingAttributes?.wrappedValue = typingAttributes
                }
                parent.onTextChange(result.attributedText)
                parent.attributedText = result.attributedText
                parent.selectedRange = textView.selectedRange
                return false
            }
            if text == "\n",
               range.length == 0,
               let result = formattingController.splitParagraphAfterHeading(in: attributed, at: range.location) {
                textView.attributedText = result.attributedText
                textView.selectedRange = result.selectedRange ?? NSRange(location: 0, length: 0)
                if var typingAttributes = result.typingAttributes {
                    if shouldClearLinkTypingAttribute {
                        typingAttributes.removeValue(forKey: .link)
                    }
                    textView.typingAttributes = typingAttributes
                    parent.typingAttributes?.wrappedValue = typingAttributes
                }
                parent.onTextChange(result.attributedText)
                parent.attributedText = result.attributedText
                parent.selectedRange = textView.selectedRange
                return false
            }
            if text == "\n",
               range.length == 0,
               !hadLinkTypingAttribute,
               FolioRichTextEditor.shouldAllowTextEdit(in: range, markers: markers) {
                var attributes = textView.typingAttributes
                if shouldClearLinkTypingAttribute {
                    attributes.removeValue(forKey: .link)
                }
                if attributes[.font] == nil {
                    attributes[.font] = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
                }
                let newline = NSAttributedString(string: "\n", attributes: attributes)
                textView.textStorage.replaceCharacters(in: range, with: newline)
                textView.selectedRange = NSRange(location: range.location + newline.length, length: 0)
                textView.typingAttributes = attributes
                parent.typingAttributes?.wrappedValue = attributes
                parent.attributedText = textView.attributedText
                parent.selectedRange = textView.selectedRange
                parent.onTextChange(textView.attributedText)
                return false
            }
            return FolioRichTextEditor.shouldAllowTextEdit(
                in: range,
                markers: markers)
        }

        private func clearLinkTypingAttribute(in textView: UITextView) {
            var typingAttributes = textView.typingAttributes
            typingAttributes.removeValue(forKey: .link)
            textView.typingAttributes = typingAttributes
            parent.typingAttributes?.wrappedValue = typingAttributes
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isSynchronizingUIView else { return }
            parent.selectedRange = textView.selectedRange
            var typingAttributes = textView.typingAttributes
            if textView.attributedText.length == 0 {
                typingAttributes[.font] = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
                typingAttributes[.foregroundColor] = UIColor(Color.folioInk)
            } else if isCaretInEmptyParagraph(in: textView) || isCaretInEmptyBlockquote(in: textView) {
                typingAttributes[.font] = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
                typingAttributes[.foregroundColor] = UIColor(Color.folioInk)
            } else if let currentFont = fontAtCurrentCaret(in: textView) {
                typingAttributes[.font] = currentFont
            }
            if hasInlineBoldAtCurrentSelection(in: textView) {
                typingAttributes[FolioRichTextFormat.inlineBoldAttribute] = true
            } else {
                typingAttributes.removeValue(forKey: FolioRichTextFormat.inlineBoldAttribute)
            }
            textView.typingAttributes = typingAttributes
            parent.typingAttributes?.wrappedValue = typingAttributes
        }

        private func isCaretInEmptyParagraph(in textView: UITextView) -> Bool {
            let selectedRange = textView.selectedRange
            guard selectedRange.length == 0, textView.attributedText.length > 0 else { return false }

            let string = textView.attributedText.string as NSString
            let paragraph = string.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
            let hasTrailingNewline = paragraph.length > 0
                && string.character(at: NSMaxRange(paragraph) - 1) == 10
            let contentLength = paragraph.length - (hasTrailingNewline ? 1 : 0)
            return contentLength == 0
        }

        private func isCaretInEmptyBlockquote(in textView: UITextView) -> Bool {
            let selectedRange = textView.selectedRange
            guard selectedRange.length == 0, textView.attributedText.length > 0 else { return false }

            let string = textView.attributedText.string as NSString
            let paragraph = string.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
            let marker = FolioRichTextFormat.blockquoteMarker as NSString
            guard paragraph.length >= marker.length,
                  string.substring(with: NSRange(location: paragraph.location, length: marker.length)) == marker as String else {
                return false
            }

            let hasTrailingNewline = paragraph.length > 0
                && string.character(at: NSMaxRange(paragraph) - 1) == 10
            let contentLength = paragraph.length - marker.length - (hasTrailingNewline ? 1 : 0)
            return contentLength == 0
        }

        private func fontAtCurrentCaret(in textView: UITextView) -> UIFont? {
            let selectedRange = textView.selectedRange
            guard selectedRange.length == 0, textView.attributedText.length > 0 else { return nil }

            let string = textView.attributedText.string as NSString
            let paragraph = string.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
            let contentLength = paragraph.length > 0
                && string.character(at: NSMaxRange(paragraph) - 1) == 10
                ? paragraph.length - 1
                : paragraph.length
            guard contentLength > 0 else { return nil }

            let contentEnd = paragraph.location + contentLength
            let location = min(max(selectedRange.location, paragraph.location), contentEnd - 1)
            return textView.attributedText.attribute(.font, at: location, effectiveRange: nil) as? UIFont
        }

        private func hasInlineBoldAtCurrentSelection(in textView: UITextView) -> Bool {
            let selectedRange = textView.selectedRange
            guard textView.attributedText.length > 0 else { return false }

            if selectedRange.length == 0 {
                let string = textView.attributedText.string as NSString
                let paragraph = string.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
                let contentLength = paragraph.length > 0
                    && string.character(at: NSMaxRange(paragraph) - 1) == 10
                    ? paragraph.length - 1
                    : paragraph.length
                guard contentLength > 0 else { return false }

                let contentEnd = paragraph.location + contentLength
                let location = min(max(selectedRange.location, paragraph.location), contentEnd - 1)
                return textView.attributedText.attribute(
                    FolioRichTextFormat.inlineBoldAttribute,
                    at: location,
                    effectiveRange: nil
                ) as? Bool == true
            }

            guard NSMaxRange(selectedRange) <= textView.attributedText.length else { return false }
            var isBold = true
            var foundAttribute = false
            textView.attributedText.enumerateAttribute(
                FolioRichTextFormat.inlineBoldAttribute,
                in: selectedRange,
                options: []
            ) { value, _, stop in
                foundAttribute = true
                if value as? Bool != true {
                    isBold = false
                    stop.pointee = true
                }
            }
            return foundAttribute && isBold
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onEditingChanged?(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingChanged?(false)
        }
    }
}

extension FolioRichTextEditor {
    static func shouldSynchronizeSelection(
        current: NSRange,
        desired: NSRange,
        textLength: Int
    ) -> Bool {
        desired.location >= 0
            && desired.length >= 0
            && NSMaxRange(desired) <= textLength
            && current != desired
    }

    static func makeDefaultAttributedText() -> NSAttributedString {
        return NSAttributedString(string: "", attributes: [:])
    }

    static func shouldPublishContentChange(
        from oldValue: NSAttributedString,
        to newValue: NSAttributedString
    ) -> Bool {
        oldValue != newValue
    }

    static func attributedTextFromHTML(_ html: String) -> NSAttributedString {
        if containsOnlySupportedSemanticTags(in: html), let parsed = parseSemanticHTML(html) {
            return parsed
        }
        return fallbackAttributedText(from: html)
    }

    static func fallbackAttributedText(from html: String) -> NSAttributedString {
        guard let data = html.data(using: .utf8) else { return makeDefaultAttributedText() }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributed = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            migrateFonts(in: mutable)
            removeUnsupportedLinks(from: mutable)
            return mutable
        }
        return NSAttributedString(string: html)
    }

    private static func containsOnlySupportedSemanticTags(in html: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "<\\s*/?\\s*([a-zA-Z][a-zA-Z0-9]*)[^>]*>") else {
            return true
        }
        let htmlString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: htmlString.length))
        for match in matches where match.numberOfRanges > 1 {
            let name = htmlString.substring(with: match.range(at: 1)).lowercased()
            if !supportedSemanticTags.contains(name) { return false }
        }
        return true
    }

    private static let supportedSemanticTags: Set<String> = [
        "h1", "h2", "h3", "p", "ul", "ol", "li", "blockquote",
        "strong", "b", "em", "i", "span", "a"
    ]

    static func bodyFontSize(from style: String?) -> CGFloat? {
        guard let style else { return nil }
        let parts = style.lowercased().split(separator: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("font-size") else { continue }
            let value = trimmed.drop(while: { $0 != ":" })
            let digits = value.filter { $0.isNumber }
            guard let size = Double(digits), !digits.isEmpty else { return nil }
            return CGFloat(size)
        }
        return nil
    }

    static func htmlFromAttributedText(_ attributedText: NSAttributedString) -> String {
        let string = attributedText.string as NSString
        var blocks: [String] = []
        var location = 0
        var openListTag: String?
        var listItems: [String] = []
        var lastParagraphWasListItem = false

        func flushList() {
            guard let tag = openListTag else { return }
            blocks.append("<\(tag)>\(listItems.joined())</\(tag)>")
            openListTag = nil
            listItems.removeAll()
        }

        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }
            let rawText = string.substring(with: paragraphRange)
            let text = rawText.hasSuffix("\n") ? String(rawText.dropLast()) : rawText
            let textLength = (text as NSString).length
            let contentRange = NSRange(location: paragraphRange.location, length: textLength)

            let font = attributedText.attribute(.font, at: paragraphRange.location, effectiveRange: nil) as? UIFont
            let size = font?.pointSize ?? FolioRichTextFormat.bodyFontSize

            if text.isEmpty {
                flushList()
                blocks.append("<p></p>")
                lastParagraphWasListItem = false
            } else if isHeadingFont(font, size: size) {
                flushList()
                let tag = size >= FolioRichTextFormat.heading1FontSize ? "h1" : (size >= FolioRichTextFormat.heading2FontSize ? "h2" : "h3")
                blocks.append("<\(tag)>\(inlineHTML(for: text, in: attributedText, range: contentRange, skipBold: true))</\(tag)>")
                lastParagraphWasListItem = false
            } else if text.hasPrefix(FolioRichTextFormat.bulletMarker) {
                if openListTag != "ul" {
                    flushList()
                    openListTag = "ul"
                }
                let body = String(text.dropFirst(2))
                let bodyRange = NSRange(location: contentRange.location + 2, length: max(0, contentRange.length - 2))
                listItems.append("<li>\(inlineHTML(for: body, in: attributedText, range: bodyRange, skipBold: false))</li>")
                lastParagraphWasListItem = true
            } else if let markerLength = FolioRichTextFormat.orderedListMarkerLength(in: text) {
                if openListTag != "ol" {
                    flushList()
                    openListTag = "ol"
                }
                let body = (text as NSString).substring(from: markerLength)
                let bodyRange = NSRange(location: contentRange.location + markerLength, length: max(0, contentRange.length - markerLength))
                listItems.append("<li>\(inlineHTML(for: body, in: attributedText, range: bodyRange, skipBold: false))</li>")
                lastParagraphWasListItem = true
            } else if text.hasPrefix(FolioRichTextFormat.blockquoteMarker),
                      hasBlockquoteStyle(attributedText, at: paragraphRange.location) {
                flushList()
                let markerLength = (FolioRichTextFormat.blockquoteMarker as NSString).length
                let body = String(text.dropFirst(markerLength))
                let bodyRange = NSRange(location: contentRange.location + markerLength, length: max(0, contentRange.length - markerLength))
                blocks.append("<blockquote>\(inlineHTML(for: body, in: attributedText, range: bodyRange, skipBold: false))</blockquote>")
                lastParagraphWasListItem = false
            } else {
                flushList()
                blocks.append("<p>\(inlineHTML(for: text, in: attributedText, range: contentRange, skipBold: false))</p>")
                lastParagraphWasListItem = false
            }

            let next = NSMaxRange(paragraphRange)
            if next <= location { break }
            location = next
        }
        flushList()
        if string.length > 0, string.character(at: string.length - 1) == 10, !lastParagraphWasListItem {
            blocks.append("<p></p>")
        }
        return blocks.joined(separator: "\n")
    }

    private static func inlineHTML(for text: String, in attributed: NSAttributedString, range: NSRange, skipBold: Bool) -> String {
        var result = ""
        attributed.enumerateAttributes(in: range, options: []) { attrs, attrRange, _ in
            var segment = (attributed.string as NSString).substring(with: attrRange)
            segment = escapeHTML(segment)
            if let url = supportedLinkURL(from: attrs[.link]) {
                segment = "<a href=\"\(escapeAttribute(url.absoluteString))\">\(segment)</a>"
            }
            if hasTextDecoration(.underlineStyle, in: attrs) {
                segment = "<span style=\"text-decoration:underline\">\(segment)</span>"
            }
            if hasTextDecoration(.strikethroughStyle, in: attrs) {
                segment = "<span style=\"text-decoration:line-through\">\(segment)</span>"
            }
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                let isInlineBold = attrs[FolioRichTextFormat.inlineBoldAttribute] as? Bool == true
                if isInlineBold || (!skipBold && traits.contains(.traitBold)) {
                    segment = "<strong>\(segment)</strong>"
                }
                if traits.contains(.traitItalic) { segment = "<em>\(segment)</em>" }
                let size = font.pointSize
                if abs(size - defaultBodyFontSize) > 0.1 {
                    segment = "<span style=\"font-size:\(Int(size))px\">\(segment)</span>"
                }
            }
        result += segment
        }
        return result
    }

    private static func hasTextDecoration(_ key: NSAttributedString.Key, in attrs: [NSAttributedString.Key: Any]) -> Bool {
        guard let value = attrs[key] else { return false }
        if let style = value as? NSUnderlineStyle { return style.rawValue != 0 }
        if let number = value as? NSNumber { return number.intValue != 0 }
        return false
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ text: String) -> String {
        escapeHTML(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func isSupportedLinkURL(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }

    fileprivate static func supportedLinkURL(from value: Any?) -> URL? {
        let url: URL?
        if let value = value as? URL {
            url = value
        } else if let value = value as? String {
            url = URL(string: value)
        } else {
            url = nil
        }
        guard let url, isSupportedLinkURL(url) else { return nil }
        return url
    }

    private static func removeUnsupportedLinks(from attributed: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            if supportedLinkURL(from: value) == nil {
                attributed.removeAttribute(.link, range: range)
            }
        }
    }

    private static func parseSemanticHTML(_ html: String) -> NSAttributedString? {
        let wrapped = "<root>\(html)</root>"
        guard let data = wrapped.data(using: .utf8) else { return nil }
        let parser = SemanticHTMLParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return nil }
        let result = parser.result
        if result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return result
    }

    fileprivate static func hasBlockquoteStyle(_ attributedText: NSAttributedString, at location: Int) -> Bool {
        guard let style = attributedText.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle else {
            return false
        }
        return style.headIndent == FolioRichTextFormat.blockquoteIndent
    }

    static func shouldAllowTextEdit(in range: NSRange, markers: [NSRange]) -> Bool {
        for marker in markers {
            let intersection = NSIntersectionRange(range, marker)
            if intersection.length == 0 {
                // A zero-length edit is a caret insertion. If the caret lies inside a
                // marker (e.g. between the "•" and the tab), typing would corrupt it,
                // so reject it. Otherwise this marker isn't touched at all.
                if range.length == 0 && NSLocationInRange(range.location, marker) {
                    return false
                }
                continue
            }
            if range.length == 0 {
                return false
            }
            // A selection that partially overlaps a marker (e.g. not deleting it whole)
            // would leave a broken marker behind. Reject partial overlap, but let a
            // selection that fully covers the marker through so whole items and
            // select-all + delete still work.
            let markerFullyCovered = marker.location >= range.location
                && NSMaxRange(marker) <= NSMaxRange(range)
            if !markerFullyCovered {
                return false
            }
        }
        return true
    }

    static func formattingMarkerRanges(in attributedText: NSAttributedString) -> [NSRange] {
        let string = attributedText.string as NSString
        var ranges: [NSRange] = []
        var location = 0
        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let rawText = string.substring(with: paragraphRange)
            if rawText.hasPrefix(FolioRichTextFormat.bulletMarker) {
                ranges.append(NSRange(location: paragraphRange.location, length: (FolioRichTextFormat.bulletMarker as NSString).length))
            } else if let length = FolioRichTextFormat.orderedListMarkerLength(in: rawText) {
                ranges.append(NSRange(location: paragraphRange.location, length: length))
            } else if rawText.hasPrefix(FolioRichTextFormat.blockquoteMarker),
                      hasBlockquoteStyle(attributedText, at: paragraphRange.location) {
                ranges.append(NSRange(location: paragraphRange.location, length: (FolioRichTextFormat.blockquoteMarker as NSString).length))
            }
            let next = NSMaxRange(paragraphRange)
            if next <= location { break }
            location = next
        }
        return ranges
    }

    static func attributedTextWithoutMarkers(_ attributedText: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        for range in formattingMarkerRanges(in: attributedText).reversed() {
            mutable.deleteCharacters(in: range)
        }
        return mutable
    }

    static func markdownFromAttributedText(_ attributedText: NSAttributedString) -> String {
        let string = attributedText.string as NSString
        var result = ""
        var location = 0
        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let rawText = string.substring(with: paragraphRange)
            let content = rawText.hasSuffix("\n") ? String(rawText.dropLast()) : rawText
            let contentLength = (content as NSString).length
            let contentRange = NSRange(location: paragraphRange.location, length: contentLength)

            result += markdownLine(for: content, in: attributedText, range: contentRange) + "\n"

            let next = NSMaxRange(paragraphRange)
            if next <= location { break }
            location = next
        }
        return result
    }

    private static func markdownLine(for text: String, in attributed: NSAttributedString, range: NSRange) -> String {
        guard range.length > 0 else { return "" }

        let font = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        let size = font?.pointSize ?? FolioRichTextFormat.bodyFontSize

        if isHeadingFont(font, size: size) {
            let prefix = size >= FolioRichTextFormat.heading1FontSize ? "#" : (size >= FolioRichTextFormat.heading2FontSize ? "##" : "###")
            return "\(prefix) \(text)"
        }

        if text.hasPrefix(FolioRichTextFormat.bulletMarker) {
            let body = String(text.dropFirst(2))
            let bodyRange = NSRange(location: range.location + 2, length: range.length - 2)
            return "- \(inlineMarkdown(body, in: attributed, range: bodyRange))"
        }

        if let markerLength = FolioRichTextFormat.orderedListMarkerLength(in: text) {
            let numberPrefix = (text as NSString).substring(to: markerLength - 1)
            let body = (text as NSString).substring(from: markerLength)
            let bodyRange = NSRange(location: range.location + markerLength, length: range.length - markerLength)
            return "\(numberPrefix) \(inlineMarkdown(body, in: attributed, range: bodyRange))"
        }

        if text.hasPrefix(FolioRichTextFormat.blockquoteMarker),
           hasBlockquoteStyle(attributed, at: range.location) {
            let markerLength = (FolioRichTextFormat.blockquoteMarker as NSString).length
            let body = String(text.dropFirst(markerLength))
            let bodyRange = NSRange(location: range.location + markerLength, length: range.length - markerLength)
            return "> \(inlineMarkdown(body, in: attributed, range: bodyRange))"
        }

        return inlineMarkdown(text, in: attributed, range: range)
    }

    private static func inlineMarkdown(_ text: String, in attributed: NSAttributedString, range: NSRange) -> String {
        var result = ""
        attributed.enumerateAttributes(in: range, options: []) { attrs, attrRange, _ in
            let substring = (attributed.string as NSString).substring(with: attrRange)
            var formatted = substring
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { formatted = "**\(formatted)**" }
                if traits.contains(.traitItalic) { formatted = "*\(formatted)*" }
            }
            result += formatted
        }
        return result
    }

    private static let defaultBodyFontSize = FolioRichTextFormat.bodyFontSize

    private static func isHeadingFont(_ font: UIFont?, size: CGFloat) -> Bool {
        guard size >= FolioRichTextFormat.heading3FontSize else { return false }
        guard let font else { return false }
        let traits = font.fontDescriptor.fontAttributes[.traits] as? [UIFontDescriptor.TraitKey: Any]
        let weight = (traits?[.weight] as? NSNumber).map { CGFloat(truncating: $0) }
        let expectedWeight = FolioRichTextFormat.headingFontWeight(for: size).rawValue
        let isConfiguredHeading = weight == expectedWeight
            || font.fontDescriptor.postscriptName
                == UIFont.systemFont(
                    ofSize: size,
                    weight: FolioRichTextFormat.headingFontWeight(for: size)
                ).fontDescriptor.postscriptName
        let isLegacyBoldHeading = font.fontDescriptor.symbolicTraits.contains(.traitBold)
        return isConfiguredHeading || isLegacyBoldHeading
    }

    private static func makeBodyFont(bold: Bool, italic: Bool, size: CGFloat = defaultBodyFontSize) -> UIFont {
        var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
        if bold { symbolicTraits.insert(.traitBold) }
        if italic { symbolicTraits.insert(.traitItalic) }

        let base = UIFont.systemFont(ofSize: size)
        var fontAttributes = base.fontDescriptor.fontAttributes
        fontAttributes[.traits] = [
            UIFontDescriptor.TraitKey.symbolic: symbolicTraits.rawValue,
            UIFontDescriptor.TraitKey.weight: bold ? UIFont.Weight.bold : UIFont.Weight.regular
        ]
        let descriptor = UIFontDescriptor(fontAttributes: fontAttributes)
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func migrateFonts(in attributed: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let traits = font.fontDescriptor.symbolicTraits
            let newFont = makeBodyFont(bold: traits.contains(.traitBold), italic: traits.contains(.traitItalic), size: font.pointSize)
            attributed.removeAttribute(.font, range: range)
            attributed.addAttribute(.font, value: newFont, range: range)
        }
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return nil }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private final class SemanticHTMLParser: NSObject, XMLParserDelegate {
    let result = NSMutableAttributedString()

    private struct Block {
        let baseSize: CGFloat
        let baseWeight: UIFont.Weight
        let startLocation: Int
        let style: BlockStyle
    }

    private enum BlockStyle {
        case paragraph
        case heading
        case blockquote
        case listItem
    }

    private enum ListType {
        case unordered
        case ordered
    }

    private var blockStack: [Block] = []
    private var boldDepth = 0
    private var italicDepth = 0
    private var listTypeStack: [ListType] = []
    private var orderedCounterStack: [Int] = []
    private var spanStyleStack: [SpanStyle] = []
    private var linkHrefStack: [URL?] = []

    private struct SpanStyle {
        let fontSize: CGFloat?
        let underline: Bool
        let strikethrough: Bool
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let normalizedName = elementName.lowercased()
        switch normalizedName {
        case "h1", "h2", "h3":
            let size: CGFloat = normalizedName == "h1" ? FolioRichTextFormat.heading1FontSize
                : (normalizedName == "h2" ? FolioRichTextFormat.heading2FontSize : FolioRichTextFormat.heading3FontSize)
            pushBlock(
                baseSize: size,
                baseWeight: FolioRichTextFormat.headingFontWeight(for: size),
                style: .heading
            )
        case "p":
            pushBlock(baseSize: FolioRichTextFormat.bodyFontSize, baseWeight: .regular, style: .paragraph)
        case "blockquote":
            pushBlock(baseSize: FolioRichTextFormat.bodyFontSize, baseWeight: .regular, style: .blockquote)
        case "ul":
            listTypeStack.append(.unordered)
        case "ol":
            listTypeStack.append(.ordered)
            orderedCounterStack.append(0)
        case "li":
            pushBlock(baseSize: FolioRichTextFormat.bodyFontSize, baseWeight: .regular, style: .listItem)
            appendListMarker()
        case "strong", "b":
            boldDepth += 1
        case "em", "i":
            italicDepth += 1
        case "span":
            let style = attributeDict["style"] ?? ""
            let lowercased = style.lowercased()
            spanStyleStack.append(
                SpanStyle(
                    fontSize: FolioRichTextEditor.bodyFontSize(from: style),
                    underline: lowercased.contains("text-decoration:underline"),
                    strikethrough: lowercased.contains("text-decoration:line-through")
                )
            )
        case "a":
            linkHrefStack.append(FolioRichTextEditor.supportedLinkURL(from: attributeDict["href"]))
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName.lowercased() {
        case "h1", "h2", "h3", "p", "blockquote", "li":
            popBlock()
        case "ul":
            if !listTypeStack.isEmpty { listTypeStack.removeLast() }
        case "ol":
            if !listTypeStack.isEmpty { listTypeStack.removeLast() }
            if !orderedCounterStack.isEmpty { orderedCounterStack.removeLast() }
        case "strong", "b":
            boldDepth = max(0, boldDepth - 1)
        case "em", "i":
            italicDepth = max(0, italicDepth - 1)
        case "span":
            if !spanStyleStack.isEmpty { spanStyleStack.removeLast() }
        case "a":
            if !linkHrefStack.isEmpty { linkHrefStack.removeLast() }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let top = blockStack.last else { return }
        let style = spanStyleStack.last
        let size = style?.fontSize ?? top.baseSize
        let weight = boldDepth > 0 ? FolioRichTextFormat.inlineBoldFontWeight : top.baseWeight
        let font = makeFont(size: size, weight: weight, italic: italicDepth > 0)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(Color.folioInk)
        ]
        if boldDepth > 0 {
            attributes[FolioRichTextFormat.inlineBoldAttribute] = true
        }
        if style?.underline == true {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if style?.strikethrough == true {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let url = linkHrefStack.last ?? nil {
            attributes[.link] = url
        }
        result.append(NSAttributedString(string: string, attributes: attributes))
    }

    private func pushBlock(baseSize: CGFloat, baseWeight: UIFont.Weight, style: BlockStyle) {
        blockStack.append(
            Block(baseSize: baseSize, baseWeight: baseWeight, startLocation: result.length, style: style)
        )
    }

    private func popBlock() {
        guard let block = blockStack.popLast() else { return }
        applyParagraphStyle(for: block)
        result.append(NSAttributedString(string: "\n"))
    }

    private func appendListMarker() {
        let type = listTypeStack.last ?? .unordered
        let marker: String
        if type == .unordered {
            marker = FolioRichTextFormat.bulletMarker
        } else {
            let index: Int
            if orderedCounterStack.isEmpty {
                index = 1
            } else {
                index = orderedCounterStack[orderedCounterStack.count - 1] + 1
                orderedCounterStack[orderedCounterStack.count - 1] = index
            }
            marker = "\(index).\t"
        }
        let font = makeFont(size: FolioRichTextFormat.bodyFontSize, weight: .regular, italic: false)
        result.append(NSAttributedString(string: marker, attributes: [.font: font]))
    }

    private func applyParagraphStyle(for block: Block) {
        switch block.style {
        case .blockquote:
            // A blockquote must keep its marker even when it has no visible content,
            // otherwise <blockquote></blockquote> collapses into a plain paragraph.
            let marker = FolioRichTextFormat.blockquoteMarker
            let contentLength = result.length - block.startLocation
            let markerAttributed = NSAttributedString(
                string: marker,
                attributes: [.font: makeFont(size: FolioRichTextFormat.bodyFontSize, weight: .regular, italic: false)]
            )
            result.insert(markerAttributed, at: block.startLocation)
            let affectedRange = NSRange(location: block.startLocation, length: contentLength + (marker as NSString).length)
            let style = NSMutableParagraphStyle()
            style.headIndent = FolioRichTextFormat.blockquoteIndent
            style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
            result.addAttribute(.paragraphStyle, value: style, range: affectedRange)
            result.addAttribute(.foregroundColor, value: UIColor(Color.folioInkMuted), range: affectedRange)
        case .listItem:
            guard block.startLocation < result.length else { return }
            let range = NSRange(location: block.startLocation, length: result.length - block.startLocation)
            let style = NSMutableParagraphStyle()
            style.headIndent = FolioRichTextFormat.listIndent
            style.firstLineHeadIndent = 0
            result.addAttribute(.paragraphStyle, value: style, range: range)
        case .heading, .paragraph:
            break
        }
    }

    private func makeFont(size: CGFloat, weight: UIFont.Weight, italic: Bool) -> UIFont {
        var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
        if weight == FolioRichTextFormat.inlineBoldFontWeight { symbolicTraits.insert(.traitBold) }
        if italic { symbolicTraits.insert(.traitItalic) }

        let base = UIFont.systemFont(ofSize: size)
        var fontAttributes = base.fontDescriptor.fontAttributes
        fontAttributes[.traits] = [
            UIFontDescriptor.TraitKey.symbolic: symbolicTraits.rawValue,
            UIFontDescriptor.TraitKey.weight: weight
        ]
        let descriptor = UIFontDescriptor(fontAttributes: fontAttributes)
        return UIFont(descriptor: descriptor, size: size)
    }
}

final class FolioTextView: UITextView {
    var canUndo = false
    var canRedo = false
    var onBlockquoteKeyCommand: (() -> Void)?
    var onUnorderedListKeyCommand: (() -> Void)?
    var onOrderedListKeyCommand: (() -> Void)?
    var onUndoKeyCommand: (() -> Void)?
    var onRedoKeyCommand: (() -> Void)?
    private var lastUndoShortcutTime: Date = .distantPast
    private var lastRedoShortcutTime: Date = .distantPast

    func applyBlockquotePresentation() {
        accessibilityLabel = FolioRichTextEditor.attributedTextWithoutMarkers(attributedText).string
        let string = attributedText.string as NSString
        for marker in FolioRichTextEditor.formattingMarkerRanges(in: attributedText) {
            guard string.substring(with: marker) == FolioRichTextFormat.blockquoteMarker else {
                continue
            }
            let paragraph = string.paragraphRange(for: NSRange(location: marker.location, length: 0))
            let paragraphContentLength = paragraph.length
                - marker.length
                - (paragraph.length > 0 && string.character(at: NSMaxRange(paragraph) - 1) == 10 ? 1 : 0)
            let markerFontSize = paragraphContentLength > 0
                ? FolioRichTextFormat.hiddenMarkerFontSize
                : FolioRichTextFormat.bodyFontSize
            let currentFont = textStorage.attribute(.font, at: marker.location, effectiveRange: nil) as? UIFont
            let currentColor = textStorage.attribute(.foregroundColor, at: marker.location, effectiveRange: nil) as? UIColor
            guard currentFont?.pointSize != markerFontSize || currentColor != .clear else {
                continue
            }
            textStorage.addAttributes([
                .font: UIFont.systemFont(ofSize: markerFontSize),
                .foregroundColor: UIColor.clear
            ], range: marker)
        }
        setNeedsDisplay()
    }

    func blockquoteRuleRects() -> [CGRect] {
        layoutManager.ensureLayout(for: textContainer)
        let string = attributedText.string as NSString
        var ruleRects: [CGRect] = []
        var activeRule: CGRect?
        var previousParagraphEnd: Int?

        for marker in FolioRichTextEditor.formattingMarkerRanges(in: attributedText) {
            guard string.substring(with: marker) == FolioRichTextFormat.blockquoteMarker else { continue }
            let paragraph = string.paragraphRange(for: NSRange(location: marker.location, length: 0))
            guard let style = attributedText.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle else {
                continue
            }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
            var paragraphMinY = CGFloat.greatestFiniteMagnitude
            var paragraphMaxY = -CGFloat.greatestFiniteMagnitude
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, _, _ in
                paragraphMinY = min(paragraphMinY, lineRect.minY + self.textContainerInset.top)
                paragraphMaxY = max(paragraphMaxY, lineRect.maxY + self.textContainerInset.top)
            }
            guard paragraphMinY.isFinite, paragraphMaxY.isFinite else { continue }

            let ruleX = textContainerInset.left
                + style.headIndent
                - FolioRichTextFormat.blockquoteRuleToContentSpacing
                - FolioRichTextFormat.blockquoteRuleWidth
            let paragraphRule = CGRect(
                x: ruleX,
                y: paragraphMinY,
                width: FolioRichTextFormat.blockquoteRuleWidth,
                height: paragraphMaxY - paragraphMinY
            )
            if previousParagraphEnd == paragraph.location, let rule = activeRule {
                activeRule = rule.union(paragraphRule)
            } else {
                if let activeRule { ruleRects.append(activeRule) }
                activeRule = paragraphRule
            }
            previousParagraphEnd = NSMaxRange(paragraph)
        }
        if let activeRule { ruleRects.append(activeRule) }
        return ruleRects
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        UIColor(Color.folioInkSoft).withAlphaComponent(0.65).setFill()
        for rule in blockquoteRuleRects() where rule.intersects(rect) {
            UIBezierPath(roundedRect: rule, cornerRadius: rule.width / 2).fill()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }


    override var undoManager: UndoManager? { nil }

    override var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []
        let blockquote = UIKeyCommand(
            input: "9",
            modifierFlags: [.command, .shift],
            action: #selector(handleBlockquoteKeyCommand)
        )
        let unorderedList = UIKeyCommand(
            input: "8",
            modifierFlags: [.command, .shift],
            action: #selector(handleUnorderedListKeyCommand)
        )
        let orderedList = UIKeyCommand(
            input: "7",
            modifierFlags: [.command, .shift],
            action: #selector(handleOrderedListKeyCommand)
        )
        let undo = UIKeyCommand(
            input: "z",
            modifierFlags: [.command],
            action: #selector(handleUndoKeyCommand)
        )
        let redoShiftZ = UIKeyCommand(
            input: "z",
            modifierFlags: [.command, .shift],
            action: #selector(handleRedoKeyCommand)
        )
        let redoY = UIKeyCommand(
            input: "y",
            modifierFlags: [.command],
            action: #selector(handleRedoKeyCommand)
        )
        commands.append(contentsOf: [blockquote, unorderedList, orderedList, undo, redoShiftZ, redoY])
        return commands
    }

    @objc func undo(_ sender: Any?) {
        handleUndoKeyCommand()
    }

    @objc func redo(_ sender: Any?) {
        handleRedoKeyCommand()
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(undo(_:)):
            return canUndo
        case #selector(redo(_:)):
            return canRedo
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    @objc private func handleUndoKeyCommand() {
        let now = Date()
        guard now.timeIntervalSince(lastUndoShortcutTime) > 0.15 else { return }
        lastUndoShortcutTime = now
        onUndoKeyCommand?()
    }

    @objc private func handleRedoKeyCommand() {
        let now = Date()
        guard now.timeIntervalSince(lastRedoShortcutTime) > 0.15 else { return }
        lastRedoShortcutTime = now
        onRedoKeyCommand?()
    }

    @objc private func handleBlockquoteKeyCommand() {
        onBlockquoteKeyCommand?()
    }

    @objc private func handleUnorderedListKeyCommand() {
        onUnorderedListKeyCommand?()
    }

    @objc private func handleOrderedListKeyCommand() {
        onOrderedListKeyCommand?()
    }
}
