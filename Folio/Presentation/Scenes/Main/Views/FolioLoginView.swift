import SwiftUI

struct FolioLoginView: View {
    let onSignIn: (FolioCredential) -> Void
    let onSignInWithApple: () -> Void

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack() {

                FolioLogoMark()
                    .padding(.top, 24)
                
                VStack(spacing: 8) {
                    Text("Folio")
                        .padding(.top, 16)
                        .font(.system(size: 40, weight: .regular, design: .serif))
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

                VStack(spacing: 14) {
                    FolioTextField(placeholder: "researcher@folio.app", text: $email)
                        .padding(.top, 54)
                    FolioTextField(placeholder: "••••••••••", text: $password, isSecure: true)

                    FolioPrimaryButton(title: "Sign in", action: { onSignIn(FolioCredential(email: email, password: password)) })

                    HStack {
                        Rectangle()
                            .fill(Color.folioLine)
                            .frame(height: 1)
                        Text("or continue with")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                        Rectangle()
                            .fill(Color.folioLine)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    FolioSecondaryButton(title: "Sign in with Apple", iconName: "applelogo", action: onSignInWithApple)
                }

                Spacer(minLength: 12)

                Text("Private by default. Your archive stays yours.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
                    .padding(.bottom, 20)
                    .padding(.top, 62)
            }
            .padding(.horizontal, 34)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    FolioBackdrop()
        .overlay {
            FolioLoginView(onSignIn: { _ in }, onSignInWithApple: {})
        }
}
