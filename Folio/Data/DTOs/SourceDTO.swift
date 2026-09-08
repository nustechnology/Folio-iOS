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

struct SourceListResponseDTO: Decodable {
    let status: String
    let data: SourceListDataDTO

    func toDomain() -> SourceListResult {
        SourceListResult(
            sources: data.sources.map { $0.toDomain() },
            pagination: data.pagination.map {
                SourcePagination(page: $0.page, limit: $0.limit, totalCount: $0.totalCount, totalPages: $0.totalPages)
            }
        )
    }
}

struct SourceListDataDTO: Decodable {
    let sources: [SourceDTO]
    let pagination: SourcePaginationDTO?
}

struct SourcePaginationDTO: Decodable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
}

struct UpdateSourceRequestDTO: Encodable {
    let title: String
    let author: String
    let content: String?
}

struct StructuredContentDTO: Decodable {
    let html: String?
    let type: String?
}

struct SourcePreviewResponseDTO: Decodable {
    let status: String
    let data: SourcePreviewDataDTO

    func toDomain() -> SourcePreview {
        SourcePreview(url: data.previewUrl)
    }
}

struct SourcePreviewDataDTO: Decodable {
    let previewUrl: String
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
    let structuredContent: StructuredContentDTO?
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
            structuredContent: structuredContent.map {
                SourceStructuredContent(html: $0.html ?? "", type: $0.type ?? "")
            },
            processingState: SourceProcessingState(rawValue: processingState) ?? .added,
            processingError: processingError ?? "",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
