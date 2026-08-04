import Foundation

struct SourceFileUploadEndpoint: APIEndpoint {
    let spaceId: String
    let title: String?
    let author: String?
    let boundary: String
    private let fileBody: Data

    init(spaceId: String, fileURL: URL, title: String?, author: String?) throws {
        self.spaceId = spaceId
        self.title = title
        self.author = author
        let boundary = "Boundary-\(UUID().uuidString)"
        self.boundary = boundary
        let fileName = fileURL.lastPathComponent
        let fileMimeType = Self.mimeTypeFor(fileName)

        var data = Data()

        func appendField(_ name: String, _ value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("spaceId", spaceId)
        appendField("sourceType", "File")
        if let title { appendField("title", title) }
        if let author { appendField("author", author) }

        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(fileMimeType)\r\n\r\n".data(using: .utf8)!)

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        while let chunk = try handle.read(upToCount: 1_000_000) {
            data.append(chunk)
        }

        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        self.fileBody = data
    }

    var path: String { "/api/v1/sources" }
    var method: HTTPMethod { .post }
    var queryItems: [URLQueryItem]? { nil }
    var requiresAuthentication: Bool { true }
    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    var body: Data? { fileBody }

    private static func mimeTypeFor(_ filename: String) -> String {
        switch (filename as NSString).pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt", "md": return "text/plain"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "csv": return "text/csv"
        case "epub": return "application/epub+zip"
        default: return "application/octet-stream"
        }
    }
}

enum SourceJSONEndpoint: APIEndpoint {
    case uploadWeb(spaceId: String, url: String, title: String?, author: String?)
    case uploadManual(spaceId: String, content: String, title: String?, author: String?)

    var path: String { "/api/v1/sources" }
    var method: HTTPMethod { .post }
    var queryItems: [URLQueryItem]? { nil }
    var requiresAuthentication: Bool { true }

    var body: Data? {
        switch self {
        case .uploadWeb(let spaceId, let url, let title, let author):
            return try? JSONEncoder().encode(UploadSourceRequestDTO(
                spaceId: spaceId, sourceType: "Web", title: title, author: author, sourceUrl: url, content: nil
            ))
        case .uploadManual(let spaceId, let content, let title, let author):
            return try? JSONEncoder().encode(UploadSourceRequestDTO(
                spaceId: spaceId, sourceType: "Manual", title: title, author: author, sourceUrl: nil, content: content
            ))
        }
    }
}

struct DeleteSourceEndpoint: APIEndpoint {
    let sourceId: String

    var path: String { "/api/v1/sources/\(sourceId)" }
    var method: HTTPMethod { .delete }
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var requiresAuthentication: Bool { true }
}

struct RetrySourceEndpoint: APIEndpoint {
    let sourceId: String

    var path: String { "/api/v1/sources/\(sourceId)/retry" }
    var method: HTTPMethod { .post }
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var requiresAuthentication: Bool { true }
}
