import Foundation

struct ApiErrorResponse: Decodable {
    let status: String
    let message: String
}
