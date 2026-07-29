import SwiftUI
import CoreText

@main
struct FolioApp: App {
    private let diContainer = AppDIContainer()

    init() {
        FolioApp.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(
                fetchUsersUseCase: diContainer.fetchUsersUseCase,
                localStorage: diContainer.localStorage
            ))
        }
    }

    private static func registerFonts() {
        let fontNames = [
            "CormorantGaramond-Medium",
            "CormorantGaramond-Bold",
            "CormorantGaramond-Regular",
            "CormorantGaramond-SemiBold"
        ]
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                Logger.error("Font not found in bundle: \(name)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let message = error?.takeRetainedValue().localizedDescription ?? "unknown"
                Logger.error("Failed to register font \(name): \(message)")
            }
        }
    }
}
