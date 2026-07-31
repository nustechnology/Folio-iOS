import SwiftUI

struct FolioPlaceholderView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let onOpenAccountSettings: () -> Void
    let userInitial: String

    var body: some View {
        VStack {
            Spacer(minLength: 24)

            FolioTopBar(
                title: title,
                subtitle: subtitle,
                trailing: [AnyView(buttonIcon("ellipsis")), AnyView(FolioAccountAvatarButton(initial: userInitial, size: 36, action: onOpenAccountSettings))]
            )

            Spacer()

            FolioEmptyStateView(title: title, subtitle: subtitle, iconName: iconName)
                .padding(.horizontal, 18)

            Spacer()
        }
    }

    private func buttonIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(width: 22, height: 22)
    }
}

#Preview {
    FolioPlaceholderView(title: "Notes", subtitle: "Capture and review", iconName: "note.text", onOpenAccountSettings: {}, userInitial: "A")
}
