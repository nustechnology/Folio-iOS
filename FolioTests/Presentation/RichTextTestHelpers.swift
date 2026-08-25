@testable import Folio
import UIKit

func quotedText(_ value: String) -> NSAttributedString {
    let quotedValue = value
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { "> " + String($0) }
        .joined(separator: "\n")
    let text = NSMutableAttributedString(string: quotedValue)
    let style = NSMutableParagraphStyle()
    style.headIndent = FolioRichTextFormat.blockquoteIndent
    style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
    text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
    return text
}
