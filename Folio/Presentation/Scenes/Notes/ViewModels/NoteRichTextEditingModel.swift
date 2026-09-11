import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class NoteRichTextEditingModel: ObservableObject {
    @Published var attributedText: NSAttributedString {
        willSet {
            serializedContent = FolioRichTextEditor.htmlFromAttributedText(newValue)
            plainText = NoteLimits.plainText(from: serializedContent)
        }
    }
    private(set) var serializedContent: String
    private(set) var plainText: String
    @Published var selectedRange = NSRange(location: 0, length: 0)
    @Published var typingAttributes: [NSAttributedString.Key: Any] = [:]
    @Published var isLinkPromptPresented = false
    @Published var linkURL = ""
    @Published var linkError: String?

    private let publishingHTML: (String) -> Void
    private let formattingController = RichTextFormattingController()

    init(attributedText: NSAttributedString, publishingHTML: @escaping (String) -> Void) {
        let serializedContent = FolioRichTextEditor.htmlFromAttributedText(attributedText)
        self.attributedText = attributedText
        self.serializedContent = serializedContent
        self.plainText = NoteLimits.plainText(from: serializedContent)
        self.publishingHTML = publishingHTML
    }

    var toolbarActiveFormats: RichTextToolbar.ActiveFormats {
        let state = formattingController.activeFormats(
            in: attributedText,
            selectedRange: selectedRange,
            typingAttributes: typingAttributes
        )
        return RichTextToolbar.ActiveFormats(
            isBold: state.isBold,
            isItalic: state.isItalic,
            isHeading1: false,
            isHeading2: false,
            isHeading3: false,
            isUnorderedList: state.isUnorderedList,
            isOrderedList: state.isOrderedList,
            hasLink: state.hasLink,
            isBlockquote: state.isBlockquote
        )
    }

    func textChanged(_ value: NSAttributedString) {
        attributedText = value
        publishContent()
    }

    func applyTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let result = formattingController.toggleTrait(
            trait,
            in: attributedText,
            selectedRange: selectedRange,
            currentTypingAttributes: typingAttributes,
            appliesToTypingAttributes: true
        ) else { return }
        commitFormatting(result.attributedText)
        if let range = result.selectedRange { selectedRange = range }
        if let typingAttributes = result.typingAttributes { self.typingAttributes = typingAttributes }
    }

    func applyHeading(_ size: CGFloat) {
        guard let result = formattingController.applyHeading(fontSize: size, in: attributedText, selectedRange: selectedRange) else { return }
        commitFormatting(result.attributedText)
    }

    func applyList(ordered: Bool) {
        guard let result = formattingController.applyListStyle(ordered: ordered, in: attributedText, selectedRange: selectedRange) else { return }
        commitFormatting(result.attributedText)
        if let range = result.selectedRange { selectedRange = range }
    }

    func applyBlockquote() {
        guard let result = formattingController.applyBlockquote(in: attributedText, selectedRange: selectedRange) else { return }
        commitFormatting(result.attributedText)
        if let range = result.selectedRange { selectedRange = range }
        if let typingAttributes = result.typingAttributes { self.typingAttributes = typingAttributes }
    }

    func presentLinkPrompt() -> Bool {
        guard selectedRange.length > 0 else {
            linkError = nil
            return false
        }
        linkURL = ""
        linkError = nil
        isLinkPromptPresented = true
        return true
    }

    @discardableResult
    func applyLink() -> Bool {
        let urlString = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString),
              FolioRichTextEditor.isSupportedLinkURL(url),
              let result = formattingController.applyLink(url, in: attributedText, selectedRange: selectedRange) else {
            linkError = String(localized: "Invalid URL")
            return false
        }
        commitFormatting(result.attributedText)
        if let range = result.selectedRange { selectedRange = range }
        linkError = nil
        isLinkPromptPresented = false
        return true
    }

    private func commitFormatting(_ value: NSAttributedString) {
        guard FolioRichTextEditor.shouldPublishContentChange(from: attributedText, to: value) else { return }
        attributedText = value
        publishContent()
    }

    private func publishContent() {
        publishingHTML(serializedContent)
    }
}
