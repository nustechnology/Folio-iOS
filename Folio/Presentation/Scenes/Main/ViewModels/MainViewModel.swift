import Foundation
import Combine

@MainActor
final class MainViewModel: ViewModelProtocol {
    @Published private(set) var state: ViewState<[User]> = .idle

    private let fetchUsersUseCase: any FetchUsersUseCaseProtocol

    init(fetchUsersUseCase: any FetchUsersUseCaseProtocol) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    func handle(_ action: MainView.Action) {
        switch action {
        case .onAppear:
            Task { await loadUsers() }
        case .refresh:
            Task { await loadUsers() }
        case .didTapUser(let user):
            state = .loaded([user])
        }
    }

    private func loadUsers() async {
        state = .loading

        do {
            let users = try await fetchUsersUseCase.execute()
            state = .loaded(users)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
