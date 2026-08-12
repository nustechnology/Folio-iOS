import SwiftUI

struct FolioPlaceholderView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let onBackToSpaces: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: 24)

            FolioContentHeader(
                title: title,
                subtitle: subtitle,
                onBackToSpaces: onBackToSpaces,
                onPlusTapped: nil,
                searchText: .constant("")
            )

            Spacer()

            FolioEmptyStateView(title: title, subtitle: subtitle, iconName: iconName)
                .padding(.horizontal, 18)

            Spacer()
        }
    }
}

#Preview {
    FolioPlaceholderView(title: "Notes", subtitle: "Capture and review", iconName: "note.text", onBackToSpaces: {})
}
