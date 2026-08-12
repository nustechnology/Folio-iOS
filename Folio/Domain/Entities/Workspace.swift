import Foundation

struct Workspace: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    var name: String
    var objective: String
    var sourceCount: Int
    var noteCount: Int
    var updatedAt: Date
}

enum WorkspaceSortOption: String, CaseIterable, Equatable, Hashable, Sendable, SortOption {
    case recentlyUpdated = "recently-updated"
    case recentlyCreated = "recently-created"
    case alphabeticalAZ = "alphabetical-az"
    case alphabeticalZA = "alphabetical-za"

    var displayTitle: String {
        switch self {
        case .recentlyUpdated: return String(localized: "Recently Updated")
        case .recentlyCreated: return String(localized: "Recently Created")
        case .alphabeticalAZ: return String(localized: "Alphabetical A-Z")
        case .alphabeticalZA: return String(localized: "Alphabetical Z-A")
        }
    }
}

struct WorkspaceListQuery: Equatable, Sendable {
    let sort: WorkspaceSortOption?
    let search: String?
    let page: Int?
    let limit: Int?

    init(sort: WorkspaceSortOption? = nil, search: String? = nil, page: Int? = nil, limit: Int? = nil) {
        self.sort = sort
        self.search = search
        self.page = page
        self.limit = limit
    }

    static let initial = WorkspaceListQuery(sort: .recentlyUpdated)
}

struct WorkspacePagination: Equatable, Sendable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
}

struct WorkspaceListResult: Equatable, Sendable {
    let workspaces: [Workspace]
    let pagination: WorkspacePagination?

    var hasNextPage: Bool {
        guard let pagination else { return false }
        return pagination.page < pagination.totalPages && workspaces.count < pagination.totalCount
    }
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
