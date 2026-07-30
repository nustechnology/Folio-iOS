import SwiftUI

struct FolioSourcesView: View {
    let filters: [FolioSourceFilter]
    let selectedFilter: FolioSourceFilter
    let sources: [FolioSource]
    let onSelectFilter: (FolioSourceFilter) -> Void
    let onSelectSource: (FolioSource) -> Void
    let onSearch: () -> Void
    let onMenu: () -> Void
    let onOpenAccountSettings: () -> Void
    let userInitial: String

    @State private var query = ""

    private var filteredSources: [FolioSource] {
        guard !query.isEmpty else { return sources }
        return sources.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FolioTopBar(
                    title: "Sources",
                    subtitle: "Evidence library",
                    trailing: [
                        AnyView(Button(action: onSearch) { buttonIcon("magnifyingglass") }.buttonStyle(.plain)),
                        AnyView(Button(action: onMenu) { buttonIcon("ellipsis") }.buttonStyle(.plain)),
                        AnyView(FolioAccountAvatarButton(initial: userInitial, size: 36, action: onOpenAccountSettings))
                    ]
                )
                .padding(.top, 4)

                VStack(spacing: 0) {
                    FolioSearchField(placeholder: "Search sources", text: $query)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters) { filter in
                                Button {
                                    onSelectFilter(filter)
                                } label: {
                                    FolioPill(
                                        title: "\(filter.title) \(filter.count)",
                                        isSelected: selectedFilter == filter
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }

                VStack(spacing: 12) {
                    if filteredSources.isEmpty {
                        Text(query.isEmpty ? "No sources yet" : "No matching sources")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.folioInkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        ForEach(filteredSources) { source in
                            FolioSourceCard(source: source, onTap: { onSelectSource(source) })
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
    }

    private func buttonIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(width: 22, height: 22)
    }
}

private struct FolioSourceCard: View {
    let source: FolioSource
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            FolioCard(
                content: HStack(alignment: .top, spacing: 12) {
                    FolioKindBadge(title: source.kind.badge)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.folioInk)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(source.subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.folioInkMuted)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(source.addedText)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 8)

                    FolioStatusBadge(title: source.status.title, status: source.status)
                }
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FolioSourcesView(
        filters: FolioDesignFixtures.filters,
        selectedFilter: .all,
        sources: FolioDesignFixtures.sources,
        onSelectFilter: { _ in },
        onSelectSource: { _ in },
        onSearch: {},
        onMenu: {},
        onOpenAccountSettings: {},
        userInitial: "A"
    )
}