import Foundation

protocol AccessTokenProvider {
    var accessToken: String? { get }
}

struct SessionAccessTokenProvider: AccessTokenProvider {
    private let localStorage: LocalStorageProtocol

    init(localStorage: LocalStorageProtocol) {
        self.localStorage = localStorage
    }

    var accessToken: String? {
        guard let session: AuthTokenDTO = try? localStorage.load(forKey: StorageKey.authSession) else {
            return nil
        }
        return session.accessToken
    }
}
