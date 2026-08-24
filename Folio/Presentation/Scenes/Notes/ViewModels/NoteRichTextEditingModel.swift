import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class NoteRichTextEditingModel: ObservableObject {
    @Published var attributedText: NSAttributedString
    @Published var selectedRange = NSRange(location: 0, length: 0)
    @Published var typingAttributes: [NSAttributedString.Key: Any] = [:]
    @Published var isLinkPromptPresented = false
    @Published var linkURL = ""
    @Published var linkError: String?

    private let publishingHTML: (String) -> Void
    private let formattingController = NotebookFormattingController()

    init(attributedText: NSAttributedString, publishingHTML: @escaping (String) -> Void) {
        self.attributedText = attributedText
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
            isUnorderedList: state.isUnorderedList,
            isOrderedList: state.isOrderedList,
            hasLink: state.hasLink
        )
    }

    func textChanged(_ value: NSAttributedString) {
        guard value != attributedText else { return }
        attributedText = value
        publishContent(value)
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
        publishContent(value)
    }

    private func publishContent(_ value: NSAttributedString) {
        publishingHTML(FolioRichTextEditor.htmlFromAttributedText(value))
    }
}
