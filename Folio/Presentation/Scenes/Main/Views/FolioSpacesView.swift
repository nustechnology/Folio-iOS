import SwiftUI

struct FolioSpacesView: View {
    let spaces: [FolioSpace]
    let onSelectSources: () -> Void
    let onSelectAsk: () -> Void
    let onSearch: () -> Void
    let onOpenAccountSettings: () -> Void
    let userInitial: String

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                FolioTopBar(
                    title: "Folio",
                    subtitle: "My Spaces",
                    trailing: [
                        AnyView(Button(action: onSearch) { buttonIcon("magnifyingglass") }.buttonStyle(.plain).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()).accessibilityLabel("Search")),
                        AnyView(FolioAccountAvatarButton(initial: userInitial, size: 36, action: onOpenAccountSettings))
                    ]
                )
                .padding(.top, 4)

                VStack(spacing: 12) {
                    ForEach(spaces) { space in
                        FolioSpaceCard(space: space, onTap: onSelectSources)
                    }
                }
                .padding(.horizontal, 18)

                FolioCard(
                    content: VStack(alignment: .leading, spacing: 12) {
                        Text("A focused workspace for research threads, sourced answers, and private synthesis.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.folioInkMuted)
                        HStack(spacing: 12) {
                            FolioPill(title: "Sources", isSelected: true)
                            FolioPill(title: "Ask")
                            FolioPill(title: "Notes")
                        }
                    }
                )
                .padding(.horizontal, 18)
                .padding(.top, 2)

                FolioPrimaryButton(title: "Open Sources", action: onSelectSources)
                    .padding(.horizontal, 18)

                FolioSecondaryButton(title: "Open Ask", iconName: "sparkle", action: onSelectAsk)
                    .padding(.horizontal, 18)

                Spacer(minLength: 8)
            }
            .padding(.bottom, 26)
        }
    }

    private func buttonIcon(_ systemName: String, border: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(border ? Color.folioGold : Color.clear, lineWidth: 1)
            )
    }
}

private struct FolioSpaceCard: View {
    let space: FolioSpace
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.folioInk, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.folioSurface)
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(Color.folioInk, lineWidth: 1)
                            .frame(width: 8, height: 8)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(space.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(space.sourceCount) sources • \(space.noteCount) notes")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.folioInkMuted)
            }
            .padding(.vertical, 17)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.folioLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FolioSpacesView(spaces: FolioDesignFixtures.spaces, onSelectSources: {}, onSelectAsk: {}, onSearch: {}, onOpenAccountSettings: {}, userInitial: "A")
}