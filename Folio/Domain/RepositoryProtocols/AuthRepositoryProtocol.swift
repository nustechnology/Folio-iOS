import Foundation

protocol AuthRepositoryProtocol {
    func signUp(name: String, email: String, password: String) async throws -> AuthToken
    func signIn(email: String, password: String) async throws -> AuthToken
    func refreshToken(_ refreshToken: String) async throws -> AuthToken
    func signOut() throws
    func signOutAwaitingCancellation() async throws
    func getCurrentSession() -> AuthToken?
}

extension AuthRepositoryProtocol {
    func signOutAwaitingCancellation() async throws { try signOut() }
}
