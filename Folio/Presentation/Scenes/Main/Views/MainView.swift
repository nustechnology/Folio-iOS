import SwiftUI

struct MainView: View {
    enum Action {
        case onAppear
        case refresh
        case didTapUser(User)
    }

    @StateObject var viewModel: MainViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Folio")
                .task { viewModel.handle(.onAppear) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Color.clear

        case .loading:
            LoadingView("Loading users...")

        case .loaded(let users):
            userList(users)

        case .error(let message):
            ErrorView(message: message) {
                viewModel.handle(.refresh)
            }
        }
    }

    private func userList(_ users: [User]) -> some View {
        List(users) { user in
            HStack {
                VStack(alignment: .leading) {
                    Text(user.name)
                        .font(.headline)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.handle(.didTapUser(user))
            }
        }
        .refreshable {
            viewModel.handle(.refresh)
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel(fetchUsersUseCase: FetchUsersUseCase(userRepository: UserRepository(
        networkService: NetworkService(baseURL: URL(string: "https://jsonplaceholder.typicode.com")!),
        localStorage: UserDefaultsStorage()
    ))))
}
