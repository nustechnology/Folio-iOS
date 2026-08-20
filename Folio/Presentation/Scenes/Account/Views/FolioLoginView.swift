import SwiftUI

struct FolioLoginView: View {
    @ObservedObject var viewModel: MainViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var showCreateAccount = false

    var body: some View {
        ScrollView {
            VStack {
                FolioLogoMark()
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    Text(String(localized: "Folio"))
                        .padding(.top, 16)
                        .font(.custom("CormorantGaramond-Medium", size: 40))
                        .foregroundStyle(Color.folioInk)

                    Text(String(localized: "PRIVATE RESEARCH. GROUNDED ANSWERS."))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color.folioGold)
                }
                .padding(.bottom, 14)

                Rectangle()
                    .fill(Color.folioGold.opacity(0.65))
                    .frame(width: 145, height: 1)
                    .padding(.bottom, 27)

                Text(String(localized: "Your sources, notes and citations in one private archive."))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.folioInkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 56)

                VStack(spacing: 14) {
                    FolioTextField(
                        placeholder: String(localized: "researcher@folio.app"),
                        text: $email,
                        error: emailError,
                        keyboardType: .emailAddress
                    )
                    .padding(.top, 54)

                    FolioTextField(
                        placeholder: "••••••••••",
                        text: $password,
                        isSecure: true,
                        error: passwordError
                    )

                    FolioPrimaryButton(
                        title: String(localized: "Sign in"),
                        isLoading: viewModel.state.authLoading,
                        action: { submitSignIn() }
                    )

                    #if DEBUG
                    HStack {
                        Rectangle()
                            .fill(Color.folioLine)
                            .frame(height: 1)
                        Text(String(localized: "or continue with"))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                        Rectangle()
                            .fill(Color.folioLine)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    FolioSecondaryButton(
                        title: String(localized: "Sign in with Apple"),
                        iconName: "applelogo",
                        action: { viewModel.handle(.signInWithApple) }
                    )
                    #endif
                }

                Spacer(minLength: 16)

                Button {
                    showCreateAccount = true
                } label: {
                    Text(String(localized: "Don't have an account? Create an account"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
                .buttonStyle(.plain)

                Text(String(localized: "Private by default. Your archive stays yours."))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
                    .padding(.bottom, 20)
                    .padding(.top, 62)
            }
            .padding(.horizontal, 34)
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(isPresented: $showCreateAccount) {
            FolioBackdrop()
                .overlay {
                    FolioCreateAccountView(viewModel: viewModel)
                }
                .folioToast(message: $viewModel.toastMessage)
        }
        .folioToast(message: $viewModel.toastMessage)
    }

    private func validateEmail() {
        if email.isEmpty {
            emailError = nil
        } else if !Validator.isValidEmail(email) {
            emailError = String(localized: "Please enter a valid email address.")
        } else {
            emailError = nil
        }
    }

    private func submitSignIn() {
        emailError = nil
        passwordError = nil
        if email.isEmpty {
            emailError = String(localized: "Please enter your email address.")
        } else {
            validateEmail()
        }
        if password.isEmpty {
            passwordError = String(localized: "Please enter your password.")
        }
        guard emailError == nil, passwordError == nil, !email.isEmpty, !password.isEmpty else { return }
        viewModel.handle(.signIn(email: email, password: password))
    }
}

#Preview {
    FolioBackdrop()
        .overlay {
            FolioLoginView(viewModel: MainViewModel(
                fetchUsersUseCase: PreviewFetchUsersUseCase(),
                fetchMeUseCase: PreviewFetchMeUseCase(),
                localStorage: PreviewStorage(),
                signUpUseCase: PreviewSignUpUseCase(),
                signInUseCase: PreviewSignInUseCase(),
                signOutUseCase: PreviewSignOutUseCase(),
                refreshTokenUseCase: PreviewRefreshTokenUseCase(),
                fetchWorkspacesUseCase: FetchWorkspacesUseCase(repository: PreviewWorkspaceRepository()),
                createWorkspaceUseCase: CreateWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
                updateWorkspaceUseCase: UpdateWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
                deleteWorkspaceUseCase: DeleteWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
                uploadSourceUseCase: PreviewUploadSourceUseCase(),
                fetchSourcesUseCase: PreviewLoginFetchSourcesUseCase(),
                updateSourceUseCase: PreviewLoginUpdateSourceUseCase(),
                fetchSourceDetailUseCase: PreviewLoginFetchSourceDetailUseCase(),
                fetchSourcePreviewUseCase: PreviewLoginFetchSourcePreviewUseCase(),
                fetchNotebookUseCase: PreviewLoginFetchNotebookUseCase(),
                saveNotebookUseCase: PreviewLoginSaveNotebookUseCase()
            ))
        }
}

private struct PreviewFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
}

private struct PreviewFetchMeUseCase: FetchMeUseCaseProtocol {
    func execute() async throws -> UserIdentity { UserIdentity(name: "Alice", email: "alice@example.com") }
}

private struct PreviewSignUpUseCase: SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewSignInUseCase: SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewSignOutUseCase: SignOutUseCaseProtocol {
    func execute() throws {}
}

private struct PreviewRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw PreviewError.unavailable }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw PreviewError.unavailable }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw PreviewError.unavailable }
    func deleteSource(id: String) async throws { throw PreviewError.unavailable }
    func retrySource(id: String) async throws -> Source { throw PreviewError.unavailable }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewLoginFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult { throw PreviewError.unavailable }
}

private struct PreviewLoginUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String) async throws -> Source { throw PreviewError.unavailable }
}

private struct PreviewLoginFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source { throw PreviewError.unavailable }
}

private struct PreviewLoginFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview { throw PreviewError.unavailable }
}

private struct PreviewLoginFetchNotebookUseCase: FetchNotebookUseCaseProtocol {
    func execute(spaceId: String) async throws -> NotebookFetchResult {
        NotebookFetchResult(
            entry: NotebookEntry(id: "", researchSpaceId: spaceId, content: "", createdAt: Date(), updatedAt: Date()),
            preservedOfflineDraft: false)
    }
}

private struct PreviewLoginSaveNotebookUseCase: SaveNotebookUseCaseProtocol {
    func execute(entry: NotebookEntry) async throws {}
}
