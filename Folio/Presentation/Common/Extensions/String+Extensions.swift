import Foundation

extension String {
    var firstLetter: String {
        guard let letter = first else { return "" }
        return String(letter)
    }
}
