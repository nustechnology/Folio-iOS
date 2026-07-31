import Foundation

protocol AuthRepositoryProtocol {
    func signUp(name: String, email: String, password: String) async throws -> AuthToken
    func signIn(email: String, password: String) async throws -> AuthToken
    func refreshToken(_ refreshToken: String) async throws -> AuthToken
    func signOut()
    func getCurrentSession() -> AuthToken?
}
