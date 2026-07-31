import Foundation

struct AuthToken: Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userName: String?
    let userEmail: String?

    var isValid: Bool { expiresAt > Date() }
}
