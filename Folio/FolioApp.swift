import SwiftUI
import CoreText

@main
struct FolioApp: App {
    private let diContainer = AppDIContainer()

    init() {
        UserDefaults.standard.removeObject(forKey: StorageKey.authSession)
        FolioApp.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(
                fetchUsersUseCase: diContainer.fetchUsersUseCase,
                fetchMeUseCase: diContainer.fetchMeUseCase,
                localStorage: diContainer.sessionStorage,
                signUpUseCase: diContainer.signUpUseCase,
                signInUseCase: diContainer.signInUseCase,
                signOutUseCase: diContainer.signOutUseCase,
                refreshTokenUseCase: diContainer.refreshTokenUseCase,
                passwordResetUseCase: diContainer.passwordResetUseCase,
                fetchWorkspacesUseCase: diContainer.fetchWorkspacesUseCase,
                createWorkspaceUseCase: diContainer.createWorkspaceUseCase,
                updateWorkspaceUseCase: diContainer.updateWorkspaceUseCase,
                deleteWorkspaceUseCase: diContainer.deleteWorkspaceUseCase,
                uploadSourceUseCase: diContainer.uploadSourceUseCase,
                fetchSourcesUseCase: diContainer.fetchSourcesUseCase,
                updateSourceUseCase: diContainer.updateSourceUseCase,
                fetchSourceDetailUseCase: diContainer.fetchSourceDetailUseCase,
                fetchSourcePreviewUseCase: diContainer.fetchSourcePreviewUseCase,
                fetchNotebookUseCase: diContainer.fetchNotebookUseCase,
                saveNotebookUseCase: diContainer.saveNotebookUseCase
            ),
            fetchNotesUseCase: diContainer.fetchNotesUseCase,
            fetchNoteUseCase: diContainer.fetchNoteUseCase,
            updateNoteUseCase: diContainer.updateNoteUseCase,
            deleteNoteUseCase: diContainer.deleteNoteUseCase,
            createNoteUseCase: diContainer.createNoteUseCase,
            convertNoteToSourceUseCase: diContainer.convertNoteToSourceUseCase,
            uploadSourceUseCase: diContainer.uploadSourceUseCase,
            fetchAskSuggestionsUseCase: diContainer.fetchAskSuggestionsUseCase,
            streamAskAnswerUseCase: diContainer.streamAskAnswerUseCase,
            fetchAskConversationsUseCase: diContainer.fetchAskConversationsUseCase,
            fetchAskConversationDetailUseCase: diContainer.fetchAskConversationDetailUseCase,
            sendFeedbackUseCase: diContainer.sendFeedbackUseCase,
            createSavedAnswerNoteUseCase: diContainer.createSavedAnswerNoteUseCase,
            deleteConversationUseCase: diContainer.deleteConversationUseCase,
            renameConversationUseCase: diContainer.renameConversationUseCase)
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
