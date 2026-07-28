import SwiftUI

enum ViewState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case error(String)

    var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}
