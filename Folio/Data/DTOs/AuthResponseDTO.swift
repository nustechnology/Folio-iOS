import Foundation

struct AuthResponseDTO: Decodable {
    let status: String
    let data: AuthDataDTO
}

struct AuthDataDTO: Decodable {
    let user: AuthUserDTO?
    let accessToken: String
    let refreshToken: String
}

struct AuthUserDTO: Decodable {
    let id: String
    let name: String
    let email: String
    let createdAt: String
    let lastActiveAt: String
}

extension AuthResponseDTO {
    func toDomain() -> AuthToken {
        AuthToken(
            accessToken: data.accessToken,
            refreshToken: data.refreshToken,
            expiresAt: JWTDecoder.decodeExpiry(data.accessToken),
            userName: data.user?.name,
            userEmail: data.user?.email
        )
    }
}
