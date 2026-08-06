import SwiftUI

struct FolioSearchHeader: View {
    let title: String
    let subtitle: String
    let searchPlaceholder: String
    let userInitial: String
    @Binding var searchText: String
    let onOpenAccountSettings: () -> Void
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FolioTopBar(
                title: title,
                subtitle: subtitle,
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

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.folioHomeSearchPlaceholder)

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text(searchPlaceholder)
                        .foregroundStyle(Color.folioHomeSearchPlaceholder)
                )
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button(action: onClearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.folioHomeSearchPlaceholder)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .foregroundStyle(Color.white)
            .background(Color.folioHomeSearchField)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
        .background(Color.folioHomeHeader)
    }
}
