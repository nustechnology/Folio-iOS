import Foundation

struct UserDTO: Codable {
    let id: Int
    let name: String
    let email: String
}

extension UserDTO {
    func toDomain() -> User {
        User(id: id, name: name, email: email)
    }
}
