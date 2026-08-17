import Foundation

struct NotebookEntry: Equatable, Sendable {
    let id: String
    let researchSpaceId: String
    var content: String
    let createdAt: Date
    var updatedAt: Date
}
