import SwiftUI

struct FolioCreateAccountView: View {
    @ObservedObject var viewModel: MainViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var confirmPasswordError: String? = nil

    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    FolioBackButton(title: "Folio")
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 2)

                Text("PRIVATE ARCHIVE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.folioInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    Text("Create your private archive.")
                        .font(.custom("CormorantGaramond-Medium", size: 28))
                        .foregroundStyle(Color.folioInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 56)

                    Text("Start with a secure workspace for sources, citation and notes")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)
                }

                VStack(spacing: 16) {
                    FolioTextField(
                        label: "Name",
                        placeholder: "Alex Morgan",
                        text: $name
                    )

                    FolioTextField(
                        label: "Email",
                        placeholder: "researcher@folio.app",
                        text: $email,
                        error: emailError,
                        keyboardType: .emailAddress
                    )

                    FolioTextField(
                        label: "Password",
                        placeholder: "••••••••••",
                        text: $password,
                        isSecure: true,
                        error: passwordError
                    )

                    FolioTextField(
                        label: "Confirm Password",
                        placeholder: "••••••••••",
                        text: $confirmPassword,
                        isSecure: true,
                        error: confirmPasswordError
                    )

                    FolioPrimaryButton(
                        title: "Create Account",
                        isLoading: viewModel.state.authLoading,
                        action: { submitSignUp() }
                    )
                    .padding(.top, 16)

                    #if DEBUG
                    FolioSecondaryButton(
                        title: "Sign in with Apple",
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
                    Text("Already have an account? Sign in")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 34)
            .frame(maxWidth: .infinity)
        }
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

    private func validatePassword() {
        if password.isEmpty {
            passwordError = nil
        } else if !Validator.isValidPassword(password) {
            passwordError = String(localized: "Password must be at least 4 characters long.")
        } else {
            passwordError = nil
        }
    }

    private func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            confirmPasswordError = nil
        } else if confirmPassword != password {
            confirmPasswordError = String(localized: "Passwords do not match.")
        } else {
            confirmPasswordError = nil
        }
    }

    private func submitSignUp() {
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
        validateEmail()
        validatePassword()
        validateConfirmPassword()
        guard emailError == nil,
              passwordError == nil,
              confirmPasswordError == nil,
              !email.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty else { return }
        viewModel.handle(.signUp(name: name, email: email, password: password))
    }
}

#Preview {
    FolioBackdrop()
        .overlay {
            FolioCreateAccountView(viewModel: MainViewModel(
                fetchUsersUseCase: PreviewAuthFetchUsersUseCase(),
                localStorage: UserDefaultsStorage(),
                signUpUseCase: PreviewAuthSignUpUseCase(),
                signInUseCase: PreviewAuthSignInUseCase(),
                signOutUseCase: PreviewAuthSignOutUseCase(),
                refreshTokenUseCase: PreviewAuthRefreshTokenUseCase(),
                workspaceRepository: PreviewWorkspaceRepository()
            ))
        }
}

private struct PreviewAuthFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
}

private struct PreviewAuthSignUpUseCase: SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date(), userName: nil, userEmail: nil)
    }
}

private struct PreviewAuthSignInUseCase: SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date(), userName: nil, userEmail: nil)
    }
}

private struct PreviewAuthSignOutUseCase: SignOutUseCaseProtocol {
    func execute() {}
}

private struct PreviewAuthRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date(), userName: nil, userEmail: nil)
    }
}
