import Foundation

struct UploadSourceRequestDTO: Encodable {
    let spaceId: String
    let sourceType: String
    let title: String?
    let author: String?
    let sourceUrl: String?
    let content: String?
}

struct SourceResponseDTO: Decodable {
    let status: String
    let data: SourceDataDTO
}

struct SourceDataDTO: Decodable {
    let source: SourceDTO
}

struct SourceDTO: Decodable {
    let id: String
    let researchSpaceId: String
    let sourceType: String
    let title: String
    let author: String
    let sourceUrl: String?
    let fileName: String?
    let fileSize: Int?
    let fileType: String?
    let pageCount: Int?
    let characterCount: Int?
    let content: String?
    let processingState: String
    let processingError: String? // nil when success
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> Source {
        Source(
            id: id,
            researchSpaceId: researchSpaceId,
            sourceType: SourceType(rawValue: sourceType) ?? .web,
            title: title,
            author: author,
            sourceUrl: sourceUrl ?? "",
            fileName: fileName ?? "",
            fileSize: fileSize ?? 0,
            fileType: fileType ?? "",
            pageCount: pageCount ?? 0,
            characterCount: characterCount ?? 0,
            content: content ?? "",
            processingState: SourceProcessingState(rawValue: processingState) ?? .added,
            processingError: processingError ?? "",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
