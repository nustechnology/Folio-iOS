import SwiftUI
import UIKit

@MainActor
final class RichTextFormattingController {
    struct Result {
        let attributedText: NSAttributedString
        let selectedRange: NSRange?
        let typingAttributes: [NSAttributedString.Key: Any]?
    }

    struct ActiveFormats {
        let isBold: Bool
        let isItalic: Bool
        let isHeading1: Bool
        let isHeading2: Bool
        let isHeading3: Bool
        let isUnorderedList: Bool
        let isOrderedList: Bool
        let hasLink: Bool
        let isBlockquote: Bool
    }
}
