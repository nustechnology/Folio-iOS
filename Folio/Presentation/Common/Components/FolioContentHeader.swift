import SwiftUI

struct FolioContentHeader: View {
    let title: String
    let subtitle: String
    let onBackToSpaces: () -> Void
    var onPlusTapped: (() -> Void)?

    var searchPlaceholder: String?
    @Binding var searchText: String
    var onClearSearch: (() -> Void)?
    var onSortTapped: (() -> Void)?
    var isSortActive: Bool = false

    private var showSearchBar: Bool {
        searchPlaceholder != nil
    }

    var body: some View {
        VStack(spacing: 0) {
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
                trailing: {
                    if let action = onPlusTapped {
                        return [AnyView(
                            Button(action: action) {
                                Image(systemName: "plus")
                                    .font(.system(size: FolioFontSize.body, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Add"))
                        )]
                    }
                    return []
                }()
            )

            if showSearchBar {
                HStack(spacing: 8) {
                    searchField

                    if onSortTapped != nil {
                        Button(action: { onSortTapped?() }) {
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
                }
                .padding(.horizontal, 18)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, showSearchBar ? 16 : 0)
        .background(Color.folioHomeHeader)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.folioHomeSearchPlaceholder)

            TextField(
                "",
                text: $searchText,
                prompt: Text(searchPlaceholder ?? "")
                    .foregroundStyle(Color.folioHomeSearchPlaceholder)
            )
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { onClearSearch?() }) {
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
