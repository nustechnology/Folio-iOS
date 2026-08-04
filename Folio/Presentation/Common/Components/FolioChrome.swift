import SwiftUI

struct FolioLogoMark: View {
    var body: some View {
        Image("FolioLogoMark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 86, height: 86)
    }
}

struct FolioTopBar: View {
    let title: String
    let subtitle: String
    var leading: AnyView? = nil
    var trailing: [AnyView] = []
    var dark: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if let leading {
                leading
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(dark ? Color.white : Color.folioInk)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(dark ? Color.white.opacity(0.76) : Color.folioInkMuted)
            }

            Spacer(minLength: 0)

            ForEach(Array(trailing.enumerated()), id: \.offset) { _, item in
                item
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(dark ? Color.folioOlive : Color.clear)
    }
}

struct FolioBottomTabBar: View {
    let selectedTab: FolioTab
    let onSelectTab: (FolioTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FolioTab.allCases) { tab in
                Button {
                    onSelectTab(tab)
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .top) {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.folioGold)
                                    .frame(width: 34, height: 3)
                                    .offset(y: -8)
                            }

                            Image(systemName: tab.iconName)
                                .font(.system(size: 16, weight: .medium))
                                .frame(height: 22)
                        }

                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.folioGold : Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.folioOliveDark)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.folioGold.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 6)
    }
}
