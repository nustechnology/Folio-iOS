import Foundation

struct ApiErrorResponse: Decodable {
    let status: String
    let message: String
    let code: String?
}
