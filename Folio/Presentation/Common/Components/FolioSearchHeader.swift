import SwiftUI

struct FolioSearchHeader: View {
    let title: String
    let subtitle: String
    let searchPlaceholder: String
    let userInitial: String
    @Binding var searchText: String
    let onOpenAccountSettings: () -> Void
    let onClearSearch: () -> Void
    let onSortTapped: () -> Void
    let isSortActive: Bool

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
                searchField

                Button(action: onSortTapped) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.folioHomeSearchPlaceholder)

                        if isSortActive {
                            Circle()
                                .fill(Color.folioDanger)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle()
                                        .stroke(Color.folioHomeSearchField, lineWidth: 1.5)
                                }
                                .offset(x: 2, y: -4)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .background(Color.folioHomeSearchField)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Sort"))
                .accessibilityHint(String(localized: "Opens sort options"))
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
        .background(Color.folioHomeHeader)
    }

    private var searchField: some View {
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
                .accessibilityLabel(String(localized: "Clear search"))
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46)
        .foregroundStyle(Color.white)
        .background(Color.folioHomeSearchField)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
