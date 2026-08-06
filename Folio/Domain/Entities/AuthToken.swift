import Foundation

struct AuthToken: Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    var isValid: Bool { expiresAt > Date() }
}
