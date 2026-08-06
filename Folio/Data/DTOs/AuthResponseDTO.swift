import Foundation

struct AuthResponseDTO: Decodable {
    let status: String
    let data: AuthDataDTO
}

struct AuthDataDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}

extension AuthResponseDTO {
    func toDomain() -> AuthToken {
        AuthToken(
            accessToken: data.accessToken,
            refreshToken: data.refreshToken,
            expiresAt: JWTDecoder.decodeExpiry(data.accessToken)
        )
    }
}
