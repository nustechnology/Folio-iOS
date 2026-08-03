import Foundation

struct Workspace: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    var name: String
    var objective: String
    var sourceCount: Int
    var noteCount: Int
    var updatedAt: Date
}

enum WorkspaceRepositoryError: LocalizedError, Equatable {
    case notFound
    case validation(String)
    case unavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return String(localized: "The selected space is no longer available.")
        case .validation(let message): return message
        case .unavailable: return String(localized: "Workspace service is unavailable.")
        case .failed(let message): return message
        }
    }
}
