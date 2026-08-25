import UIKit

enum FolioRichTextFormat {
    static let inlineBoldAttribute = NSAttributedString.Key("FolioInlineBold")
    static let bodyFontSize: CGFloat = 16
    static let heading1FontSize: CGFloat = 28
    static let heading2FontSize: CGFloat = 24
    static let heading3FontSize: CGFloat = 20
    static let heading1FontWeight: UIFont.Weight = .semibold
    static let heading2FontWeight: UIFont.Weight = .medium
    static let heading3FontWeight: UIFont.Weight = .regular
    static let inlineBoldFontWeight: UIFont.Weight = .bold
    static let blockquoteRuleWidth: CGFloat = 3
    static let blockquoteRuleToContentSpacing: CGFloat = 8
    static let blockquoteIndent: CGFloat = 20
    static let hiddenMarkerFontSize: CGFloat = 0.01
    static let listIndent: CGFloat = 24
    static let bulletMarker = "•\t"
    static let blockquoteMarker = "> "

    static func headingFontWeight(for fontSize: CGFloat) -> UIFont.Weight {
        if fontSize >= heading1FontSize { return heading1FontWeight }
        if fontSize >= heading2FontSize { return heading2FontWeight }
        return heading3FontWeight
    }

    static func orderedListMarkerLength(in text: String) -> Int? {
        let ns = text as NSString
        var index = 0
        while index < ns.length {
            let character = ns.character(at: index)
            if character >= 48 && character <= 57 {
                index += 1
            } else {
                break
            }
        }
        guard index > 0, index + 2 <= ns.length else { return nil }
        let isDot = ns.character(at: index) == 46
        let isTab = ns.character(at: index + 1) == 9
        guard isDot && isTab else { return nil }
        return index + 2
    }
}
