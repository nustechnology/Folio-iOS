import SwiftUI

struct FolioAccountAvatarButton: View {
    let initial: String
    var size: CGFloat = 36
    var fillColor: Color = .folioHomeHeader
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(initial.uppercased())
                .font(.system(size: size * 0.38, weight: .medium, design: .serif))
                .foregroundStyle(Color.white)
                .frame(width: size, height: size)
                .background(fillColor)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("Account settings")
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 1)
        )
    }
}

struct FolioAccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirmation = false

    let displayName: String
    let emailAddress: String
    let onSignOut: () -> Void

    var body: some View {
        ZStack {
            Color.folioCanvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: 0) {
                        FolioAccountAvatarButton(
                            initial: displayName.firstLetter,
                            size: 104,
                            fillColor: .folioAccountAvatar
                        ) {
                        }
                        .padding(.top, 38)

                        VStack(spacing: 6) {
                            Text(displayName)
                                .font(.custom("CormorantGaramond-Medium", size: 26))
                                .foregroundStyle(Color.folioInk)

                            Text(emailAddress)
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(Color.folioInkSoft)
                        }
                        .padding(.top, 16)

                        VStack(spacing: 12) {
                            accountRow(title: "Profile settings", isDisabled: true) {}
                            accountRow(title: "Security", isDisabled: true) {}
                            accountRow(title: "Privacy & data", isDisabled: true) {}
                            accountRow(title: "Export account data", isDisabled: true) {}
                            accountRow(title: "Sign out", isDestructive: true) {
                                showSignOutConfirmation = true
                            }
                        }
                        .padding(.top, 60)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
        }
        .alert(
            "Are you sure you want to sign out?",
            isPresented: $showSignOutConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                onSignOut()
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 24)
                    .background(Color.folioHomeHeader)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)

            Text("Account settings")
                .font(.custom("CormorantGaramond-Medium", size: 28))
                .foregroundStyle(Color.folioInk)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountRow(title: String, isDestructive: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isDisabled ? Color.folioInkSoft : (isDestructive ? Color.black : Color.folioInk))

                Spacer(minLength: 16)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDisabled ? Color.folioInkSoft : Color.folioInk)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(isDisabled ? Color.white : Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isDisabled ? Color.folioInkSoft.opacity(0.8) : Color.folioRowBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
