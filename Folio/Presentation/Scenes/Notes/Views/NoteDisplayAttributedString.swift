import Foundation
import UIKit

enum NoteDisplayAttributedString {
    static func make(from html: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            attributedString: FolioRichTextEditor.attributedTextFromHTML(html)
        )
        let fullRange = NSRange(location: 0, length: result.length)

        result.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            let url: URL?
            if let value = value as? URL {
                url = value
            } else if let value = value as? String {
                url = URL(string: value)
            } else {
                url = nil
            }

            guard let url, FolioRichTextEditor.isSupportedLinkURL(url) else { return }
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }

        return result
    }
}
