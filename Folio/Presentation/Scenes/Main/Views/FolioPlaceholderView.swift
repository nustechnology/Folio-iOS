import SwiftUI

struct FolioPlaceholderView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let onOpenAccountSettings: () -> Void
    let onBackToSpaces: () -> Void
    let userInitial: String

    var body: some View {
        VStack {
            Spacer(minLength: 24)

            FolioTopBar(
                title: title,
                subtitle: subtitle,
                leading: AnyView(
                    Button(action: onBackToSpaces) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Back to My Spaces"))
                ),
                trailing: [
                    AnyView(
                        FolioAccountAvatarButton(
                            initial: userInitial,
                            size: 36,
                            action: onOpenAccountSettings
                        )
                    )
                ]
            )

            Spacer()

            FolioEmptyStateView(title: title, subtitle: subtitle, iconName: iconName)
                .padding(.horizontal, 18)

            Spacer()
        }
    }
}

#Preview {
    FolioPlaceholderView(
        title: "Notes",
        subtitle: "Capture and review",
        iconName: "note.text",
        onOpenAccountSettings: {},
        onBackToSpaces: {},
        userInitial: "A"
    )
}
