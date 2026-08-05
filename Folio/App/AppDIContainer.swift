import Foundation

final class AppDIContainer {
    lazy var networkService: NetworkServiceProtocol = {
        NetworkService(
            baseURL: AppConfiguration.apiBaseURL,
            accessTokenProvider: accessTokenProvider,
            refreshSession: { [weak self] refreshToken in
                guard let self else { throw NetworkError.unauthorized }
                _ = try await self.authRepository.refreshToken(refreshToken)
            },
            onSessionInvalidated: {
                NotificationCenter.default.post(name: .folioSessionInvalidated, object: nil)
            }
        )
    }()

    lazy var accessTokenProvider: AccessTokenProvider = {
        SessionAccessTokenProvider(localStorage: localStorage)
    }()

    lazy var localStorage: LocalStorageProtocol = {
        UserDefaultsStorage()
    }()

    lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(networkService: networkService, localStorage: localStorage)
    }()

    lazy var fetchUsersUseCase: any FetchUsersUseCaseProtocol = {
        FetchUsersUseCase(userRepository: userRepository)
    }()

    lazy var authRepository: AuthRepositoryProtocol = {
        AuthRepository(networkService: networkService, localStorage: localStorage)
    }()

    lazy var signUpUseCase: any SignUpUseCaseProtocol = {
        SignUpUseCase(authRepository: authRepository)
    }()

    lazy var signInUseCase: any SignInUseCaseProtocol = {
        SignInUseCase(authRepository: authRepository)
    }()

    lazy var refreshTokenUseCase: any RefreshTokenUseCaseProtocol = {
        RefreshTokenUseCase(authRepository: authRepository)
    }()

    lazy var signOutUseCase: any SignOutUseCaseProtocol = {
        SignOutUseCase(authRepository: authRepository)
    }()

    lazy var workspaceRepository: WorkspaceRepositoryProtocol = {
        RemoteWorkspaceRepository(networkService: networkService)
    }()

    lazy var sourceRepository: SourceRepositoryProtocol = {
        SourceRepository(networkService: networkService, baseURL: AppConfiguration.apiBaseURL, accessTokenProvider: accessTokenProvider)
    }()

    lazy var uploadSourceUseCase: any UploadSourceUseCaseProtocol = {
        UploadSourceUseCase(repository: sourceRepository)
    }()
}
