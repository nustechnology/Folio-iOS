import SwiftUI

struct FolioAccountAvatarButton: View {
    let initial: String
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(initial.uppercased())
                .font(.system(size: size * 0.38, weight: .medium, design: .serif))
                .foregroundStyle(Color.folioOliveDark)
                .frame(width: size, height: size)
                .background(Color.folioGold)
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
                VStack(spacing: 18) {
                    header

                    VStack(spacing: 24) {
                        FolioAccountAvatarButton(initial: displayName.firstLetter ?? "A", size: 104) {
                            dismiss()
                        }
                        .padding(.top, 20)

                        VStack(spacing: 8) {
                            Text(displayName)
                                .font(.custom("CormorantGaramond-Medium", size: 34))
                                .foregroundStyle(Color.folioInk)

                            Text(emailAddress)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.folioInkSoft)
                        }

                        VStack(spacing: 12) {
                            accountRow(title: "Profile settings", isDisabled: true) {}
                            accountRow(title: "Security", isDisabled: true) {}
                            accountRow(title: "Privacy & data", isDisabled: true) {}
                            accountRow(title: "Export account data", isDisabled: true) {}
                            accountRow(title: "Sign out", isDestructive: true) {
                                showSignOutConfirmation = true
                            }
                        }
                        .padding(.top, 4)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, 28)
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
        HStack(alignment: .top, spacing: 12) {
            headerIconButton("chevron.left") {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Profile")
                    .font(.custom("CormorantGaramond-Medium", size: 30))
                    .foregroundStyle(Color.folioGold.opacity(0.78))

                Text("Account settings")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
            }

            Spacer(minLength: 16)

            HStack(spacing: 18) {
                headerIconButton("magnifyingglass", isDisabled: true) {}
                headerIconButton("ellipsis", isDisabled: true) {}
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private func headerIconButton(_ systemName: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.folioInk)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .opacity(isDisabled ? 0.3 : 1.0)
        .disabled(isDisabled)
    }

    private func accountRow(title: String, isDestructive: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isDestructive ? Color.folioDanger : Color.folioInk)

                Spacer(minLength: 16)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInkMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.folioRowBorder, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private extension String {
    var firstLetter: String? {
        guard let letter = first else { return nil }
        return String(letter)
    }
}
