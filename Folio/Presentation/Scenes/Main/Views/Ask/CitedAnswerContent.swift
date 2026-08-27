import SwiftUI

// MARK: - Content parsing
// Mirrors AskPane.kt's `parseAskContent`/`AskCitationRegex` (`\[(\d+)\]`) and
// CitedAnswerContent.kt's citation resolution/rendering.

enum AskContentPart: Equatable {
    case text(String)
    case citation(Int)
}

func parseAskContent(_ content: String) -> [AskContentPart] {
    guard !content.isEmpty else { return [] }
    var parts: [AskContentPart] = []
    var remainder = content[...]

    while let openBracket = remainder.firstIndex(of: "["),
          let closeBracket = remainder[openBracket...].firstIndex(of: "]") {
        let digits = remainder[remainder.index(after: openBracket)..<closeBracket]
        if !digits.isEmpty, let index = Int(digits) {
            if openBracket > remainder.startIndex {
                parts.append(.text(String(remainder[remainder.startIndex..<openBracket])))
            }
            parts.append(.citation(index))
            remainder = remainder[remainder.index(after: closeBracket)...]
        } else {
            let nextStart = remainder.index(after: openBracket)
            parts.append(.text(String(remainder[remainder.startIndex..<nextStart])))
            remainder = remainder[nextStart...]
        }
    }
    if !remainder.isEmpty {
        parts.append(.text(String(remainder)))
    }
    return parts
}

/// Mirrors `resolveAskCitation` in CitedAnswerContent.kt: exact index match only,
/// no fallback — a `[n]` with no matching citation stays non-interactive.
func resolveCitation(_ citations: [AskCitation], index: Int) -> AskCitation? {
    citations.first { $0.index == index }
}

/// Renders as a single wrapping `Text`; each `[n]` becomes a tappable link run
/// (scheme `folio-citation://n`) so citations stay inline without breaking text flow.
func attributedAskContent(_ content: String) -> AttributedString {
    var result = AttributedString()
    for part in parseAskContent(content) {
        switch part {
        case .text(let value):
            result += AttributedString(value)
        case .citation(let index):
            var segment = AttributedString("[\(index)]")
            segment.foregroundColor = Color.folioOliveDark
            segment.font = .system(size: 13, weight: .semibold)
            segment.backgroundColor = Color.folioSurface
            segment.underlineStyle = nil
            if let url = URL(string: "folio-citation://\(index)") {
                segment.link = url
            }
            result += segment
        }
    }
    return result
}
