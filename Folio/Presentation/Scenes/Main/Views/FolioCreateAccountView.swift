import SwiftUI

struct FolioCreateAccountView: View {
    @ObservedObject var viewModel: MainViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var nameError: String? = nil
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var confirmPasswordError: String? = nil

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Folio")
                            .font(.custom("CormorantGaramond-Medium", size: 40))
                            .foregroundStyle(Color.folioInk)

                        Text("PRIVATE ARCHIVE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(Color.folioGold)
                            .padding(.top, 6)

                        Text("Create your private archive.")
                            .font(.custom("CormorantGaramond-Medium", size: 34))
                            .foregroundStyle(Color.folioInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14)

                        Text("Start with a secure workspace for sources, citations and notes.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.folioInkMuted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 28)

                    VStack(spacing: 16) {
                        FolioTextField(
                            label: String(localized: "Name"),
                            placeholder: "Jordan Lee",
                            text: $name,
                            error: nameError,
                            fieldBackground: Color.folioLoginBackground
                        )

                        FolioTextField(
                            label: String(localized: "Email"),
                            placeholder: "jordan@folio.app",
                            text: $email,
                            error: emailError,
                            keyboardType: .emailAddress,
                            fieldBackground: Color.folioLoginBackground
                        )

                        FolioTextField(
                            label: String(localized: "Password"),
                            placeholder: "••••••••••",
                            text: $password,
                            isSecure: true,
                            error: passwordError,
                            fieldBackground: Color.folioLoginBackground
                        )

                        FolioTextField(
                            label: String(localized: "Confirm password"),
                            placeholder: "••••••••••",
                            text: $confirmPassword,
                            isSecure: true,
                            error: confirmPasswordError,
                            fieldBackground: Color.folioLoginBackground
                        )
                    }

                    VStack(spacing: 16) {
                        FolioPrimaryButton(
                            title: String(localized: "Create account"),
                            isLoading: viewModel.state.authLoading,
                            action: { submitSignUp() }
                        )

                        }
                    .padding(.top, 28)

                    Spacer(minLength: 28)

                    Button {
                        dismiss()
                    } label: {
                        (
                            Text(String(localized: "Already have an account? "))
                                .foregroundStyle(Color.folioInkSoft)
                            + Text(String(localized: "Sign in"))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.folioInk)
                        )
                        .font(.system(size: 14, weight: .regular))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 34)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    private func validateName() {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameError = String(localized: "Name is required.")
        } else {
            nameError = nil
        }
    }

    private func validateEmail() {
        if email.isEmpty {
            emailError = String(localized: "Email is required.")
        } else if !Validator.isValidEmail(email) {
            emailError = String(localized: "Please enter a valid email address.")
        } else {
            emailError = nil
        }
    }

    private func validatePassword() {
        if password.isEmpty {
            passwordError = String(localized: "Password is required.")
        } else if !Validator.isValidPassword(password) {
            passwordError = String(localized: "Password must be at least 4 characters long.")
        } else {
            passwordError = nil
        }
    }

    private func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            confirmPasswordError = String(localized: "Please confirm your password.")
        } else if confirmPassword != password {
            confirmPasswordError = String(localized: "Passwords do not match.")
        } else {
            confirmPasswordError = nil
        }
    }

    private func submitSignUp() {
        nameError = nil
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
        validateName()
        validateEmail()
        validatePassword()
        validateConfirmPassword()
        guard nameError == nil,
              emailError == nil,
              passwordError == nil,
              confirmPasswordError == nil else { return }
        viewModel.handle(.signUp(name: name, email: email, password: password))
    }
}

#Preview {
    FolioBackdrop()
        .overlay {
            FolioCreateAccountView(viewModel: MainViewModel(
                fetchUsersUseCase: PreviewAuthFetchUsersUseCase(),
                fetchMeUseCase: PreviewAuthFetchMeUseCase(),
                getStoredAuthSessionUseCase: PreviewGetStoredAuthSessionUseCase(),
                signUpUseCase: PreviewAuthSignUpUseCase(),
                signInUseCase: PreviewAuthSignInUseCase(),
                signOutUseCase: PreviewAuthSignOutUseCase(),
                refreshTokenUseCase: PreviewAuthRefreshTokenUseCase(),
                fetchWorkspacesUseCase: FetchWorkspacesUseCase(repository: PreviewWorkspaceRepository()),
                createWorkspaceUseCase: CreateWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
                updateWorkspaceUseCase: UpdateWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
                deleteWorkspaceUseCase: DeleteWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
                uploadSourceUseCase: PreviewAuthUploadSourceUseCase(),
                fetchSourcesUseCase: PreviewAuthFetchSourcesUseCase(),
                updateSourceUseCase: PreviewAuthUpdateSourceUseCase(),
                fetchSourceDetailUseCase: PreviewAuthFetchSourceDetailUseCase(),
                fetchSourcePreviewUseCase: PreviewAuthFetchSourcePreviewUseCase(),
                fetchNotebookUseCase: PreviewAuthFetchNotebookUseCase(),
                saveNotebookUseCase: PreviewAuthSaveNotebookUseCase()
            ))
        }
}

private struct PreviewAuthFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
}

private struct PreviewAuthFetchMeUseCase: FetchMeUseCaseProtocol {
    func execute() async throws -> UserIdentity { UserIdentity(name: "Alice", email: "alice@example.com") }
}

private struct PreviewAuthSignUpUseCase: SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewAuthSignInUseCase: SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewAuthSignOutUseCase: SignOutUseCaseProtocol {
    func execute() {}
}

private struct PreviewAuthRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewAuthUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { fatalError("Preview") }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { fatalError("Preview") }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { fatalError("Preview") }
    func deleteSource(id: String) async throws { fatalError("Preview") }
    func retrySource(id: String) async throws -> Source { fatalError("Preview") }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewAuthFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult { fatalError("Preview") }
}

private struct PreviewAuthUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String, content: String?) async throws -> Source { fatalError("Preview") }
}

private struct PreviewAuthFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source { fatalError("Preview") }
}

private struct PreviewAuthFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview { fatalError("Preview") }
}

private struct PreviewAuthFetchNotebookUseCase: FetchNotebookUseCaseProtocol {
    func execute(spaceId: String) async throws -> NotebookFetchResult {
        NotebookFetchResult(
            entry: NotebookEntry(id: "", researchSpaceId: spaceId, content: "", createdAt: Date(), updatedAt: Date()),
            preservedOfflineDraft: false)
    }
}

private struct PreviewAuthSaveNotebookUseCase: SaveNotebookUseCaseProtocol {
    func execute(entry: NotebookEntry) async throws {}
}
