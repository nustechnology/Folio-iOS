import Foundation

struct Source: Identifiable, Equatable, Sendable {
    let id: String
    let researchSpaceId: String
    let sourceType: SourceType
    let title: String
    let author: String
    let sourceUrl: String
    let fileName: String
    let fileSize: Int
    let fileType: String
    let pageCount: Int
    let characterCount: Int
    let content: String
    let processingState: SourceProcessingState
    let processingError: String
    let createdAt: Date
    let updatedAt: Date
}

enum SourceType: String, Equatable, Sendable {
    case file = "File"
    case web = "Web"
    case manual = "Manual"
}

enum SourceProcessingState: String, Equatable, Sendable {
    case added
    case extractingText = "extracting_text"
    case indexingEvidence = "indexing_evidence"
    case ready
    case failed
}

struct SourceListQuery: Equatable, Sendable {
    let spaceId: String
    let sourceType: String?
    let processingState: String?
    let search: String?
    let sort: String?
    let page: Int?
    let limit: Int?

    init(spaceId: String, sourceType: String? = nil, processingState: String? = nil, search: String? = nil, sort: String? = "recently-added", page: Int? = nil, limit: Int? = nil) {
        self.spaceId = spaceId
        self.sourceType = sourceType
        self.processingState = processingState
        self.search = search
        self.sort = sort
        self.page = page
        self.limit = limit
    }
}

struct SourcePagination: Equatable, Sendable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
}

struct SourceListResult: Equatable, Sendable {
    let sources: [Source]
    let pagination: SourcePagination?
}

extension Source {
    func withProcessingState(_ newState: SourceProcessingState) -> Source {
        Source(
            id: id,
            researchSpaceId: researchSpaceId,
            sourceType: sourceType,
            title: title,
            author: author,
            sourceUrl: sourceUrl,
            fileName: fileName,
            fileSize: fileSize,
            fileType: fileType,
            pageCount: pageCount,
            characterCount: characterCount,
            content: content,
            processingState: newState,
            processingError: processingError,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    var badgeText: String {
        switch sourceType {
        case .web: return "WEB"
        case .manual: return "TEXT"
        case .file:
            let ext = (fileName as NSString).pathExtension.uppercased()
            if !ext.isEmpty { return ext }
            return fileType.uppercased()
        }
    }
}
