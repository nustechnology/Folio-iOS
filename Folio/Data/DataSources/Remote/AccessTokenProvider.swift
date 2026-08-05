import Foundation

protocol AccessTokenProvider {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func clearSession()
}

extension AccessTokenProvider {
    var refreshToken: String? { nil }
    func clearSession() {}
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

    var refreshToken: String? {
        guard let session: AuthTokenDTO = try? localStorage.load(forKey: StorageKey.authSession) else {
            return nil
        }
        return session.refreshToken
    }

    func clearSession() {
        localStorage.remove(forKey: StorageKey.authSession)
    }
}
