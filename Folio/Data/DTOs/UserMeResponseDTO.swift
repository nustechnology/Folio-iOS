import Foundation

struct UserMeResponseDTO: Decodable {
    let status: String
    let data: UserMeDataDTO
}

struct UserMeDataDTO: Decodable {
    let user: UserMeUserDTO
}

struct UserMeUserDTO: Decodable {
    let id: String
    let name: String
    let email: String
    let createdAt: String
    let lastActiveAt: String
}

extension UserMeResponseDTO {
    func toDomain() -> UserIdentity {
        UserIdentity(name: data.user.name, email: data.user.email)
    }
}
