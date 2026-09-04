import SwiftUI

struct FolioSourcesView: View {
    let workspaceID: String?
    let workspaceTitle: String?
    let filters: [FolioSourceFilter]
    let selectedFilter: FolioSourceFilter
    let sources: [FolioSource]
    let onSelectFilter: (FolioSourceFilter) -> Void
    let onSelectSource: (FolioSource) -> Void
    let onSearch: () -> Void
    let onMenu: () -> Void
    let onOpenAccountSettings: () -> Void
    let onBackToSpaces: () -> Void
    let userInitial: String
    let onSourceAdded: ((Source) -> Void)?
    let onSourceAsk: ((Source) -> Void)?
    let uploadSourceUseCase: (any UploadSourceUseCaseProtocol)?

    init(
        workspaceID: String? = nil,
        workspaceTitle: String? = nil,
        filters: [FolioSourceFilter],
        selectedFilter: FolioSourceFilter,
        sources: [FolioSource],
        onSelectFilter: @escaping (FolioSourceFilter) -> Void,
        onSelectSource: @escaping (FolioSource) -> Void,
        onSearch: @escaping () -> Void,
        onMenu: @escaping () -> Void,
        onOpenAccountSettings: @escaping () -> Void,
        onBackToSpaces: @escaping () -> Void,
        userInitial: String,
        onSourceAdded: ((Source) -> Void)? = nil,
        onSourceAsk: ((Source) -> Void)? = nil,
        uploadSourceUseCase: (any UploadSourceUseCaseProtocol)? = nil
    ) {
        self.workspaceID = workspaceID
        self.workspaceTitle = workspaceTitle
        self.filters = filters
        self.selectedFilter = selectedFilter
        self.sources = sources
        self.onSelectFilter = onSelectFilter
        self.onSelectSource = onSelectSource
        self.onSearch = onSearch
        self.onMenu = onMenu
        self.onOpenAccountSettings = onOpenAccountSettings
        self.onBackToSpaces = onBackToSpaces
        self.userInitial = userInitial
        self.onSourceAdded = onSourceAdded
        self.onSourceAsk = onSourceAsk
        self.uploadSourceUseCase = uploadSourceUseCase
    }

    @State private var query = ""
    @State private var showAddSheet = false
    @State private var addSourceViewModel: FolioAddSourceViewModel?

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
                    title: String(localized: "Sources"),
                    subtitle: workspaceTitle ?? String(localized: "Evidence library"),
                    leading: AnyView(
                        Button(action: onBackToSpaces) { buttonIcon("chevron.left") }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Back to My Spaces"))
                    ),
                    trailing: [
                        AnyView(Button(action: onSearch) { buttonIcon("magnifyingglass") }.buttonStyle(.plain)),
                        AnyView(Button(action: onMenu) { buttonIcon("ellipsis") }.buttonStyle(.plain)),
                        workspaceID != nil ? AnyView(addSourceButton) : AnyView(EmptyView())
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
                                        title: filter.title,
                                        isSelected: selectedFilter == filter,
                                        tint: .folioInk,
                                        fontSize: 13,
                                        backgroundColor: .folioHomeTypeFileBackground
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
                        if sources.isEmpty {
                            VStack(spacing: 20) {
                                FolioEmptyStateView(
                                    title: String(localized: "No sources yet"),
                                    subtitle: String(
                                        localized: "Add your first source to start building your research archive."
                                    ),
                                    iconName: "doc.text"
                                )

                                if workspaceID != nil, !(workspaceID?.isEmpty ?? true), uploadSourceUseCase != nil {
                                    FolioPrimaryButton(
                                        title: String(localized: "Add Source"),
                                        action: {
                                            ensureAddSourceViewModel()
                                            showAddSheet = true
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 12)
                        } else {
                            Text(String(localized: "No matching sources"))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.folioInkMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        }
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
        .sheet(isPresented: $showAddSheet) {
            addSourceSheet
        }
        .onChange(of: showAddSheet) { _, isPresented in
            if !isPresented, let vm = addSourceViewModel {
                let isTerminal = vm.state.isProcessingComplete || vm.state.isProcessingFailed
                if !vm.state.isProcessing || isTerminal {
                    vm.handle(.dismissProcessing)
                }
            }
        }
    }

    private var addSourceSheet: some View {
        let onOpened: (Source) -> Void = { source in
            onSourceAdded?(source)
        }
        let onAsk: (Source) -> Void = { source in
            onSourceAsk?(source)
        }
        let onComplete: (Source) -> Void = { source in
            onSourceAdded?(source)
        }
        if let vm = addSourceViewModel {
            return AnyView(FolioAddSourceSheet(
                viewModel: vm,
                onSourceOpened: onOpened,
                onAskSource: onAsk,
                onProcessingComplete: onComplete
            ))
        } else {
            return AnyView(EmptyView())
        }
    }

    private var addSourceButton: some View {
        Button {
            ensureAddSourceViewModel()
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(Color.folioOlive)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Add source"))
    }

    private func buttonIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(width: 22, height: 22)
    }

    private func ensureAddSourceViewModel() {
        guard addSourceViewModel == nil, let useCase = uploadSourceUseCase, let workspaceID else { return }
        let vm = FolioAddSourceViewModel(uploadUseCase: useCase, spaceId: workspaceID)
        vm.onProcessingComplete = { [onSourceAdded] source in
            onSourceAdded?(source)
        }
        addSourceViewModel = vm
    }
}

private struct FolioSourceCard: View {
    let source: FolioSource
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            FolioCard(
                content: HStack(alignment: .top, spacing: 12) {
                    FolioKindBadge(
                        title: source.kind.badge,
                        backgroundColor: source.kind.backgroundColor,
                        textColor: source.kind.textColor
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.title)
                            .font(.system(size: 12, weight: .semibold))
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
        onBackToSpaces: {},
        userInitial: "A",
        onSourceAdded: { _ in },
        onSourceAsk: { _ in }
    )
}
