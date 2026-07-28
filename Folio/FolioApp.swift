import SwiftUI

@main
struct FolioApp: App {
    private let diContainer = AppDIContainer()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(
                fetchUsersUseCase: diContainer.fetchUsersUseCase
            ))
        }
    }
}
