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
    var leading: AnyView?
    var trailing: [AnyView] = []
    var dark: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if let leading {
                leading
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: subtitle.isEmpty ? 22 : 30, weight: .regular, design: .serif))
                    .italic()
                    .lineLimit(1)
                    .foregroundStyle(dark ? Color.white : Color.folioInk)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(dark ? Color.white.opacity(0.76) : Color.folioInkMuted)
                }
            }

            Spacer(minLength: 0)

            ForEach(Array(trailing.enumerated()), id: \.offset) { _, item in
                item
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(dark ? Color.folioHomeHeader : Color.clear)
    }
}

struct FolioBottomTabBar: View {
    private enum Metrics {
        static let indicatorWidth: CGFloat = 34
        static let indicatorHeight: CGFloat = 3
        static let indicatorTopInset: CGFloat = 4
    }

    let selectedTab: FolioTab
    let onSelectTab: (FolioTab) -> Void

    private var selectedIndex: Int {
        FolioTab.allCases.firstIndex(of: selectedTab) ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            let tabWidth = proxy.size.width / CGFloat(FolioTab.allCases.count)
            let indicatorOffsetX = tabWidth * CGFloat(selectedIndex) + (tabWidth - Metrics.indicatorWidth) / 2

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.folioGold)
                    .frame(width: Metrics.indicatorWidth, height: Metrics.indicatorHeight)
                    .offset(x: indicatorOffsetX, y: Metrics.indicatorTopInset)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)

                HStack(spacing: 0) {
                    ForEach(FolioTab.allCases) { tab in
                        let isSelected = selectedTab == tab

                        Button {
                            onSelectTab(tab)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(height: 22)

                                Text(tab.title)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(isSelected ? Color.folioGold : Color.white.opacity(0.72))
                            .animation(.easeInOut(duration: 0.2), value: isSelected)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Metrics.indicatorTopInset + Metrics.indicatorHeight)
            }
        }
        .frame(height: 74)
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
