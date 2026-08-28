import SwiftUI
import UIKit

@MainActor
extension RichTextFormattingController {
    func removeEmptyBlockquote(
        in attributedText: NSAttributedString,
        editRange: NSRange
    ) -> Result? {
        let string = attributedText.string as NSString
        guard editRange.length > 0,
              editRange.location >= 0,
              NSMaxRange(editRange) <= string.length else { return nil }

        let paragraph = string.paragraphRange(for: NSRange(location: editRange.location, length: 0))
        let markerLength = (FolioRichTextFormat.blockquoteMarker as NSString).length
        guard paragraph.length >= markerLength,
              string.substring(with: NSRange(location: paragraph.location, length: markerLength)) == FolioRichTextFormat.blockquoteMarker,
              isBlockquote(paragraph, in: attributedText) else { return nil }

        let newlineLength = paragraph.length > 0 && string.character(at: NSMaxRange(paragraph) - 1) == 10 ? 1 : 0
        let contentLength = paragraph.length - markerLength - newlineLength
        let markerRange = NSRange(location: paragraph.location, length: markerLength)
        guard contentLength == 0,
              editRange.location >= markerRange.location,
              NSMaxRange(editRange) <= NSMaxRange(markerRange) else { return nil }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.replaceCharacters(in: markerRange, with: "")
        applyPlainParagraphStyle(at: paragraph.location, in: mutable)
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: paragraph.location, length: 0),
            typingAttributes: typingAttributes(at: paragraph.location, in: mutable)
        )
    }

    func applyBlockquoteEdit(
        replacementText: String,
        in attributedText: NSAttributedString,
        selectedRange: NSRange
    ) -> Result? {
        guard replacementText == "\n",
              selectedRange.length == 0 else { return nil }

        let string = attributedText.string as NSString
        guard selectedRange.location >= 0,
              selectedRange.location <= string.length else { return nil }

        let paragraph = string.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
        let markerLength = (FolioRichTextFormat.blockquoteMarker as NSString).length
        guard paragraph.length >= markerLength,
              string.substring(with: NSRange(location: paragraph.location, length: markerLength)) == FolioRichTextFormat.blockquoteMarker,
              isBlockquote(paragraph, in: attributedText) else { return nil }

        let newlineLength = paragraph.length > 0 && string.character(at: NSMaxRange(paragraph) - 1) == 10 ? 1 : 0
        let contentLength = paragraph.length - markerLength - newlineLength
        let markerEnd = paragraph.location + markerLength
        guard selectedRange.location >= markerEnd else { return nil }

        let continuationTypingAttributes = typingAttributes(at: selectedRange.location, in: attributedText)
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        if contentLength == 0 {
            let replacement = newlineLength == 1 ? "" : "\n"
            mutable.replaceCharacters(in: NSRange(location: paragraph.location, length: markerLength), with: replacement)
            applyPlainParagraphStyle(at: paragraph.location, in: mutable)
            let bodyFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
            mutable.addAttribute(.font, value: bodyFont, range: NSRange(location: paragraph.location, length: 1))
            return Result(
                attributedText: mutable,
                selectedRange: NSRange(location: paragraph.location, length: 0),
                typingAttributes: [.font: bodyFont]
            )
        }

        mutable.insert(NSAttributedString(string: "\n\(FolioRichTextFormat.blockquoteMarker)"), at: selectedRange.location)
        applyBlockquoteParagraphStyle(at: selectedRange.location + 1, in: mutable)
        let caretLocation = selectedRange.location + 1 + markerLength
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: caretLocation, length: 0),
            typingAttributes: continuationTypingAttributes
        )
    }

    func applyBlockquote(in attributedText: NSAttributedString, selectedRange: NSRange) -> Result? {
        if attributedText.length == 0 {
            return applyBlockquoteToEmpty(attributedText: attributedText)
        }

        let selectionRange = selectedRange.length > 0
            ? selectedRange
            : paragraphRange(at: selectedRange.location, in: attributedText)

        if selectionRange.length == 0,
           selectedRange.length == 0,
           selectedRange.location == attributedText.length,
           attributedText.string.hasSuffix("\n") {
            return applyBlockquoteToEnd(attributedText: attributedText, selectionRange: selectionRange)
        }

        guard selectionRange.location != NSNotFound, selectionRange.length > 0 else { return nil }
        return applyBlockquote(
            to: selectionRange,
            selectedRange: selectedRange,
            in: attributedText
        )
    }

    func isBlockquote(_ paragraph: NSRange, in attributedText: NSAttributedString) -> Bool {
        let string = attributedText.string as NSString
        guard paragraph.length >= (FolioRichTextFormat.blockquoteMarker as NSString).length,
              string.substring(with: paragraph).hasPrefix(FolioRichTextFormat.blockquoteMarker),
              let style = attributedText.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle else {
            return false
        }
        return style.headIndent == FolioRichTextFormat.blockquoteIndent
            && style.firstLineHeadIndent == FolioRichTextFormat.blockquoteIndent
    }

    private func applyBlockquoteToEmpty(attributedText: NSAttributedString) -> Result? {
        let bodyFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.append(NSAttributedString(
            string: FolioRichTextFormat.blockquoteMarker,
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(Color.folioInkMuted)
            ]
        ))
        applyBlockquoteParagraphStyle(at: 0, in: mutable)
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: mutable.length, length: 0),
            typingAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(Color.folioInk)
            ]
        )
    }

    private func applyBlockquoteToEnd(attributedText: NSAttributedString, selectionRange: NSRange) -> Result? {
        let bodyFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        let marker = FolioRichTextFormat.blockquoteMarker
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let markerRange = NSRange(location: selectionRange.location, length: (marker as NSString).length)
        mutable.append(NSAttributedString(
            string: marker,
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(Color.folioInkMuted)
            ]
        ))
        applyBlockquoteParagraphStyle(at: markerRange.location, in: mutable)
        return Result(
            attributedText: mutable,
            selectedRange: NSRange(location: NSMaxRange(markerRange), length: 0),
            typingAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(Color.folioInk)
            ]
        )
    }

    private func applyBlockquote(to selectionRange: NSRange, selectedRange: NSRange, in attributedText: NSAttributedString) -> Result? {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let originalString = attributedText.string as NSString
        let paragraphs = paragraphRanges(in: selectionRange, string: originalString)
        guard !paragraphs.isEmpty else { return nil }

        let markerLength = (FolioRichTextFormat.blockquoteMarker as NSString).length
        let allAreBlockquotes = paragraphs.allSatisfy { isBlockquote($0, in: attributedText) }
        let markerDelta = allAreBlockquotes ? -markerLength : markerLength

        for paragraph in paragraphs.reversed() {
            let currentParagraph = NSRange(location: paragraph.location, length: paragraph.length)
            if allAreBlockquotes {
                let markerRange = NSRange(location: currentParagraph.location, length: markerLength)
                mutable.replaceCharacters(in: markerRange, with: "")
                applyPlainParagraphStyle(at: currentParagraph.location, in: mutable)
                let contentLength = max(0, currentParagraph.length - markerLength)
                mutable.addAttribute(
                    .foregroundColor,
                    value: UIColor(Color.folioInk),
                    range: NSRange(location: currentParagraph.location, length: contentLength)
                )
            } else {
                mutable.replaceCharacters(
                    in: NSRange(location: currentParagraph.location, length: 0),
                    with: FolioRichTextFormat.blockquoteMarker
                )
                applyBlockquoteParagraphStyle(at: currentParagraph.location, in: mutable)
                mutable.addAttribute(
                    .foregroundColor,
                    value: UIColor(Color.folioInkMuted),
                    range: NSRange(
                        location: currentParagraph.location,
                        length: currentParagraph.length + markerLength
                    )
                )
            }
        }

        let adjustedSelection = adjustedSelectionAfterMarkerChanges(
            selectedRange,
            markerLocations: paragraphs.map(\.location),
            markerLength: markerDelta,
            textLength: mutable.length
        )
        return Result(attributedText: mutable, selectedRange: adjustedSelection, typingAttributes: nil)
    }

    private func applyBlockquoteParagraphStyle(at location: Int, in mutable: NSMutableAttributedString) {
        guard mutable.length > 0, location < mutable.length else { return }
        let paragraph = (mutable.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.blockquoteIndent
        style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        mutable.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }

    private func adjustedSelectionAfterMarkerChanges(
        _ selection: NSRange,
        markerLocations: [Int],
        markerLength: Int,
        textLength: Int
    ) -> NSRange {
        var adjustedLocation = selection.location
        var adjustedLength = selection.length
        let selectionEnd = NSMaxRange(selection)

        for markerLocation in markerLocations {
            if markerLocation <= selection.location {
                adjustedLocation += markerLength
            } else if selection.length > 0, markerLocation < selectionEnd {
                adjustedLength += markerLength
            }
        }

        return clampedSelection(
            NSRange(location: adjustedLocation, length: adjustedLength),
            to: textLength
        )
    }
}
