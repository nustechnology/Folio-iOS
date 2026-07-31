import Foundation

struct AuthTokenDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userName: String?
    let userEmail: String?
}

extension AuthTokenDTO {
    func toDomain() -> AuthToken {
        AuthToken(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt, userName: userName, userEmail: userEmail)
    }
}

extension AuthToken {
    func toDTO() -> AuthTokenDTO {
        AuthTokenDTO(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt, userName: userName, userEmail: userEmail)
    }
}
