import Foundation

struct SourceStatusEvent: Decodable {
    let sourceId: String
    let state: String
    let progress: Int
}
