import Foundation

struct AskSuggestionsResult: Equatable, Sendable {
    let suggestions: [String]
    let isDynamic: Bool
}
