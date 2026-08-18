import SwiftUI

struct AccountBottomSheet: View {
    let displayName: String
    let emailAddress: String
    let onOpenSettings: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header
            accountCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.folioSurfaceStrong)
        .presentationDetents([.medium])
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.folioInkSoft.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Account"))
                .font(.system(size: 24, design: .serif))
                .foregroundStyle(Color.black)

            Spacer()

            Button(action: onSignOut) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.folioDanger)
                    .frame(width: 34, height: 34)
                    .background(Color.folioDanger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Sign out")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    private var accountCard: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: 14) {
                Text(displayName.firstLetter.capitalized)
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.folioHomeSearchField)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)

                    Text(emailAddress)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.68))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Color.folioHomeHeader)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .accessibilityLabel("Profile settings")
    }
}
