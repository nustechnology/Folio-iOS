import SwiftUI

struct FolioLoginView: View {
    @ObservedObject var viewModel: MainViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var showCreateAccount = false
    @State private var showForgotPassword = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    FolioLogoMark()
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text("Folio")
                            .padding(.top, 16)
                            .font(.custom("CormorantGaramond-Medium", size: 40))
                            .foregroundStyle(Color.folioInk)

                        Text("PRIVATE RESEARCH. GROUNDED ANSWERS.")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.folioGold)
                    }
                    .padding(.bottom, 14)

                    Rectangle()
                        .fill(Color.folioGold.opacity(0.65))
                        .frame(width: 145, height: 1)
                        .padding(.bottom, 27)

                    Text("Your sources, notes and citations in one private archive.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 56)

                    VStack(spacing: 16) {
                        FolioTextField(
                            placeholder: "jordan@folio.app",
                            text: $email,
                            error: emailError,
                            keyboardType: .emailAddress,
                            fieldBackground: Color.folioLoginBackground
                        )

                        FolioTextField(
                            placeholder: "••••••••••",
                            text: $password,
                            isSecure: true,
                            error: passwordError,
                            fieldBackground: Color.folioLoginBackground
                        )

                        HStack {
                            Spacer()
                            Button(action: { showForgotPassword = true }) {
                                Text(String(localized: "Forgot password?"))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.folioInkMuted)
                            }
                            .buttonStyle(.plain)
                        }

                        FolioPrimaryButton(
                            title: String(localized: "Sign in"),
                            isLoading: viewModel.state.authLoading,
                            action: { submitSignIn() }
                        )
                        .padding(.top, 10)
                    }
                    .padding(.top, 40)

                    Spacer(minLength: 32)

                    Button {
                        showCreateAccount = true
                    } label: {
                        (
                            Text(String(localized: "Don't have an account? "))
                                .foregroundStyle(Color.folioInkSoft)
                            + Text(String(localized: "Sign up"))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.folioInk)
                        )
                        .font(.system(size: 14, weight: .regular))
                    }
                    .buttonStyle(.plain)

                    Text("Private by default. Your archive stays yours.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 34)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
        }
        .fullScreenCover(isPresented: $showCreateAccount) {
            FolioBackdrop()
                .overlay {
                    FolioCreateAccountView(viewModel: viewModel)
                }
                .folioToast(message: $viewModel.toastMessage)
        }
        .fullScreenCover(isPresented: $showForgotPassword) {
            FolioBackdrop()
                .overlay {
                    FolioForgotPasswordView()
                }
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
                localStorage: UserDefaultsStorage(),
                signUpUseCase: PreviewSignUpUseCase(),
                signInUseCase: PreviewSignInUseCase(),
                signOutUseCase: PreviewSignOutUseCase(),
                refreshTokenUseCase: PreviewRefreshTokenUseCase(),
                passwordResetUseCase: PreviewPasswordResetUseCase(),
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
    func execute() {}
}

private struct PreviewRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewPasswordResetUseCase: RequestPasswordResetUseCaseProtocol {
    func execute(email: String) async throws {}
}

private struct PreviewUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { fatalError("Preview") }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { fatalError("Preview") }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { fatalError("Preview") }
    func deleteSource(id: String) async throws { fatalError("Preview") }
    func retrySource(id: String) async throws -> Source { fatalError("Preview") }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewLoginFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult { fatalError("Preview") }
}

private struct PreviewLoginUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String, content: String?) async throws -> Source { fatalError("Preview") }
}

private struct PreviewLoginFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source { fatalError("Preview") }
}

private struct PreviewLoginFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview { fatalError("Preview") }
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
