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
        ScrollView {
            VStack {
                HStack {
                    FolioBackButton(title: String(localized: "Folio"))
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 2)

                Text(String(localized: "PRIVATE ARCHIVE"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.folioInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    Text(String(localized: "Create your private archive."))
                        .font(.custom("CormorantGaramond-Medium", size: 28))
                        .foregroundStyle(Color.folioInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 56)

                    Text(String(localized: "Start with a secure workspace for sources, citation and notes"))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)
                }

                VStack(spacing: 16) {
                    FolioTextField(
                        label: String(localized: "Name"),
                        placeholder: String(localized: "Alex Morgan"),
                        text: $name,
                        error: nameError
                    )

                    FolioTextField(
                        label: String(localized: "Email"),
                        placeholder: String(localized: "researcher@folio.app"),
                        text: $email,
                        error: emailError,
                        keyboardType: .emailAddress
                    )

                    FolioTextField(
                        label: String(localized: "Password"),
                        placeholder: "••••••••••",
                        text: $password,
                        isSecure: true,
                        error: passwordError
                    )

                    FolioTextField(
                        label: String(localized: "Confirm Password"),
                        placeholder: "••••••••••",
                        text: $confirmPassword,
                        isSecure: true,
                        error: confirmPasswordError
                    )

                    FolioPrimaryButton(
                        title: String(localized: "Create Account"),
                        isLoading: viewModel.state.authLoading,
                        action: { submitSignUp() }
                    )
                    .padding(.top, 16)

                    #if DEBUG
                    FolioSecondaryButton(
                        title: String(localized: "Sign in with Apple"),
                        iconName: "applelogo",
                        action: { viewModel.handle(.signInWithApple) }
                    )
                    #endif
                }
                .padding(.vertical, 13)

                Spacer(minLength: 27)

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Already have an account? Sign in"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 34)
            .frame(maxWidth: .infinity)
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
                localStorage: PreviewStorage(),
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
                fetchSourcePreviewUseCase: PreviewAuthFetchSourcePreviewUseCase()
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
    func execute() throws {}
}

private struct PreviewAuthRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewAuthUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw PreviewError.unavailable }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw PreviewError.unavailable }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw PreviewError.unavailable }
    func deleteSource(id: String) async throws { throw PreviewError.unavailable }
    func retrySource(id: String) async throws -> Source { throw PreviewError.unavailable }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewAuthFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult { throw PreviewError.unavailable }
}

private struct PreviewAuthUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String) async throws -> Source { throw PreviewError.unavailable }
}

private struct PreviewAuthFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source { throw PreviewError.unavailable }
}

private struct PreviewAuthFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview { throw PreviewError.unavailable }
}
