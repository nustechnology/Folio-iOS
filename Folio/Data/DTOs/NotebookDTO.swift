import Foundation

struct NotebookResponseDTO: Decodable {
    let status: String
    let data: NotebookDataDTO
}

struct NotebookDataDTO: Decodable {
    let notebook: NotebookDTO
}

struct NotebookDTO: Codable {
    let id: String
    let researchSpaceId: String
    let content: String
    let createdAt: Date
    var updatedAt: Date
    var needsSync: Bool
    // Server updatedAt that this cached content is based on. Used to detect a real
    // remote change without comparing the device clock against the server clock.
    var baseServerUpdatedAt: Date?

    init(
        id: String,
        researchSpaceId: String,
        content: String,
        createdAt: Date,
        updatedAt: Date,
        needsSync: Bool = false,
        baseServerUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.researchSpaceId = researchSpaceId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.baseServerUpdatedAt = baseServerUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The server returns null for id/createdAt/updatedAt when no notebook has
        // been created yet for the space. Fall back to an empty id and the current
        // time so an empty notebook loads cleanly.
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        researchSpaceId = try container.decode(String.self, forKey: .researchSpaceId)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        needsSync = try container.decodeIfPresent(Bool.self, forKey: .needsSync) ?? false
        baseServerUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .baseServerUpdatedAt)
    }

    func toDomain() -> NotebookEntry {
        NotebookEntry(
            id: id,
            researchSpaceId: researchSpaceId,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct NotebookSaveDTO: Encodable {
    let content: String
}
