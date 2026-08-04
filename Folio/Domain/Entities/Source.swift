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
}
