import SwiftUI

struct FolioSearchHeader: View {
  let title: String
  let subtitle: String
  let searchPlaceholder: String
  var userInitial: String = ""
  @Binding var searchText: String
  var onOpenAccountSettings: () -> Void = {}
  let onClearSearch: () -> Void
  let onSortTapped: () -> Void
  let isSortActive: Bool
  var leadingAction: AnyView?
  var trailingActions: [AnyView] = []
  var showsSort: Bool = true

  var body: some View {
    VStack(spacing: 0) {
      FolioTopBar(
        title: title,
        subtitle: subtitle,
        leading: leadingAction,
        trailing: trailingActions.isEmpty
          ? [
            AnyView(
              FolioAccountAvatarButton(
                initial: userInitial,
                size: 36,
                action: onOpenAccountSettings
              )
            )
          ]
          : trailingActions
      )

      HStack(spacing: FolioSpacing.sm) {
        searchField

        if showsSort {
          Button(action: onSortTapped) {
            ZStack(alignment: .topTrailing) {
              Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
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
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(String(localized: "Sort"))
          .accessibilityHint(String(localized: "Opens sort options"))
        }
      }
      .padding(.horizontal, FolioSpacing.xl2)
    }
    .padding(.top, FolioSpacing.xs)
    .padding(.bottom, FolioSpacing.xl)
    .background(Color.folioHomeHeader)
  }

  private var searchField: some View {
    HStack(spacing: FolioSpacing.sm) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(Color.folioHomeSearchPlaceholder)

      TextField(
        "",
        text: $searchText,
        prompt: Text(searchPlaceholder)
          .foregroundStyle(Color.folioHomeSearchPlaceholder)
      )
      .font(.system(size: FolioFontSize.body))
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
    .padding(.horizontal, FolioSpacing.lg2)
    .frame(maxWidth: .infinity, minHeight: FolioSize.fieldHeightXs, maxHeight: FolioSize.fieldHeightXs)
    .foregroundStyle(Color.white)
    .background(Color.folioHomeSearchField)
    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
  }
}
