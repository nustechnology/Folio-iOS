import SwiftUI

struct FolioForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var emailError: String? = nil
    @State private var isLoading = false
    @State private var hasSent = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Folio")
                            .font(.custom("CormorantGaramond-Medium", size: 40))
                            .foregroundStyle(Color.folioInk)

                        Text("PRIVATE ARCHIVE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(Color.folioGold)
                            .padding(.top, 6)

                        Text(String(localized: "Reset password"))
                            .font(.custom("CormorantGaramond-Medium", size: 34))
                            .foregroundStyle(Color.folioInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 24)

                        Text(String(localized: "Enter your email and Folio will send a secure recovery link."))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.folioInkMuted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 0) {
                        FolioTextField(
                            label: String(localized: "Email address"),
                            placeholder: "jordan@folio.app",
                            text: $email,
                            error: emailError,
                            keyboardType: .emailAddress,
                            fieldBackground: Color.folioCanvas
                        )
                        .onChange(of: email) { _, _ in
                            emailError = nil
                            hasSent = false
                        }

                        if hasSent {
                            Text(String(localized: "Recovery link sent. Check your inbox."))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.folioInkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 10)
                        }

                        FolioPrimaryButton(
                            title: String(localized: "Send recovery link"),
                            isLoading: isLoading,
                            action: { submit() }
                        )
                        .padding(.top, 20)

                        FolioSecondaryButton(
                            title: String(localized: "Back to sign in"),
                            isDisabled: isLoading,
                            action: { dismiss() }
                        )
                        .padding(.top, 10)
                    }

                    Spacer(minLength: 36)

                    FolioPrivacyCard()
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 34)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func submit() {
        emailError = nil
        if email.isEmpty {
            emailError = String(localized: "Please enter your email address.")
            return
        }
        if !Validator.isValidEmail(email) {
            emailError = String(localized: "Please enter a valid email address.")
            return
        }
        guard !isLoading else { return }
        isLoading = true
        hasSent = false
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            isLoading = false
            hasSent = true
        }
    }
}

private struct FolioPrivacyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Private by default"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.folioInk)

            Text(String(localized: "Recovery links expire quickly and never expose source data."))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.folioInkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.folioLoginBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                .stroke(Color.folioLoginBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
    }
}

#Preview {
    FolioBackdrop()
        .overlay {
            FolioForgotPasswordView()
        }
}
