import Foundation

final class AppDIContainer {
    lazy var networkService: NetworkServiceProtocol = {
        NetworkService(baseURL: AppConfiguration.apiBaseURL)
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
}
