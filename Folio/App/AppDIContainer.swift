import Foundation

final class AppDIContainer {
    lazy var networkService: NetworkServiceProtocol = {
        NetworkService(
            baseURL: AppConfiguration.apiBaseURL,
            accessTokenProvider: accessTokenProvider
        )
    }()

    lazy var accessTokenProvider: AccessTokenProvider = {
        SessionAccessTokenProvider(localStorage: sessionStorage, baseURL: AppConfiguration.apiBaseURL)
    }()

    lazy var localStorage: LocalStorageProtocol = {
        UserDefaultsStorage()
    }()

    lazy var sessionStorage: LocalStorageProtocol = {
        KeychainStorage()
    }()

    lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(networkService: networkService, localStorage: localStorage)
    }()

    lazy var fetchUsersUseCase: any FetchUsersUseCaseProtocol = {
        FetchUsersUseCase(userRepository: userRepository)
    }()

    lazy var fetchMeUseCase: any FetchMeUseCaseProtocol = {
        FetchMeUseCase(userRepository: userRepository)
    }()

    lazy var authRepository: AuthRepositoryProtocol = {
        AuthRepository(networkService: networkService, localStorage: sessionStorage)
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

    lazy var passwordResetUseCase: any RequestPasswordResetUseCaseProtocol = {
        RequestPasswordResetUseCase(authRepository: authRepository)
    }()

    lazy var signOutUseCase: any SignOutUseCaseProtocol = {
        SignOutUseCase(authRepository: authRepository)
    }()

    lazy var getStoredAuthSessionUseCase: any GetStoredAuthSessionUseCaseProtocol = {
        GetStoredAuthSessionUseCase(authRepository: authRepository)
    }()

    lazy var workspaceRepository: WorkspaceRepositoryProtocol = {
        RemoteWorkspaceRepository(networkService: networkService)
    }()

    lazy var fetchWorkspacesUseCase: any FetchWorkspacesUseCaseProtocol = {
        FetchWorkspacesUseCase(repository: workspaceRepository)
    }()

    lazy var createWorkspaceUseCase: any CreateWorkspaceUseCaseProtocol = {
        CreateWorkspaceUseCase(repository: workspaceRepository)
    }()

    lazy var updateWorkspaceUseCase: any UpdateWorkspaceUseCaseProtocol = {
        UpdateWorkspaceUseCase(repository: workspaceRepository)
    }()

    lazy var deleteWorkspaceUseCase: any DeleteWorkspaceUseCaseProtocol = {
        DeleteWorkspaceUseCase(repository: workspaceRepository)
    }()

    lazy var sourceRepository: SourceRepositoryProtocol = {
        SourceRepository(networkService: networkService, baseURL: AppConfiguration.apiBaseURL, accessTokenProvider: accessTokenProvider)
    }()

    lazy var noteRepository: NoteRepositoryProtocol = {
        NoteRepository(networkService: networkService)
    }()

    lazy var fetchNotesUseCase: any FetchNotesUseCaseProtocol = { FetchNotesUseCase(repository: noteRepository) }()
    lazy var fetchNoteUseCase: any FetchNoteUseCaseProtocol = { FetchNoteUseCase(repository: noteRepository) }()
    lazy var createNoteUseCase: any CreateNoteUseCaseProtocol = { CreateNoteUseCase(repository: noteRepository) }()
    lazy var convertNoteToSourceUseCase: any ConvertNoteToSourceUseCaseProtocol = {
        ConvertNoteToSourceUseCase(repository: noteRepository)
    }()
    lazy var updateNoteUseCase: any UpdateNoteUseCaseProtocol = { UpdateNoteUseCase(repository: noteRepository) }()
    lazy var deleteNoteUseCase: any DeleteNoteUseCaseProtocol = { DeleteNoteUseCase(repository: noteRepository) }()

    lazy var uploadSourceUseCase: any UploadSourceUseCaseProtocol = {
        UploadSourceUseCase(repository: sourceRepository)
    }()

    lazy var fetchSourcesUseCase: any FetchSourcesUseCaseProtocol = {
        FetchSourcesUseCase(repository: sourceRepository)
    }()

    lazy var updateSourceUseCase: any UpdateSourceUseCaseProtocol = {
        UpdateSourceUseCase(repository: sourceRepository)
    }()

    lazy var fetchSourceDetailUseCase: any FetchSourceDetailUseCaseProtocol = {
        FetchSourceDetailUseCase(repository: sourceRepository)
    }()

    lazy var fetchSourcePreviewUseCase: any FetchSourcePreviewUseCaseProtocol = {
        FetchSourcePreviewUseCase(repository: sourceRepository)
    }()

    lazy var notebookRepository: NotebookRepositoryProtocol = {
        NotebookRepository(localStorage: localStorage, networkService: networkService)
    }()

    lazy var fetchNotebookUseCase: any FetchNotebookUseCaseProtocol = {
        FetchNotebookUseCase(repository: notebookRepository)
    }()

    lazy var saveNotebookUseCase: any SaveNotebookUseCaseProtocol = {
        SaveNotebookUseCase(repository: notebookRepository)
    }()

    lazy var askRepository: AskRepositoryProtocol = {
        AskRepository(networkService: networkService, baseURL: AppConfiguration.apiBaseURL, accessTokenProvider: accessTokenProvider)
    }()

    lazy var fetchAskSuggestionsUseCase: any FetchAskSuggestionsUseCaseProtocol = {
        FetchAskSuggestionsUseCase(repository: askRepository)
    }()

    lazy var fetchAskConversationsUseCase: any FetchAskConversationsUseCaseProtocol = {
        FetchAskConversationsUseCase(repository: askRepository)
    }()

    lazy var fetchAskConversationDetailUseCase: any FetchAskConversationDetailUseCaseProtocol = {
        FetchAskConversationDetailUseCase(repository: askRepository)
    }()

    lazy var streamAskAnswerUseCase: any StreamAskAnswerUseCaseProtocol = {
        StreamAskAnswerUseCase(repository: askRepository)
    }()

    lazy var sendFeedbackUseCase: any SendFeedbackUseCaseProtocol = {
        SendFeedbackUseCase(repository: askRepository)
    }()

    lazy var createSavedAnswerNoteUseCase: any CreateSavedAnswerNoteUseCaseProtocol = {
        CreateSavedAnswerNoteUseCase(repository: noteRepository)
    }()

    lazy var deleteConversationUseCase: any DeleteConversationUseCaseProtocol = {
        DeleteConversationUseCase(repository: askRepository)
    }()

    lazy var renameConversationUseCase: any RenameConversationUseCaseProtocol = {
        RenameConversationUseCase(repository: askRepository)
    }()
}
