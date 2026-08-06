import Foundation

struct AuthTokenDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

extension AuthTokenDTO {
    func toDomain() -> AuthToken {
        AuthToken(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
}

extension AuthToken {
    func toDTO() -> AuthTokenDTO {
        AuthTokenDTO(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
}
