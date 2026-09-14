import SwiftUI

struct SourceListView: View {
    @StateObject private var viewModel: SourceListViewModel
    @State private var actionSheetSource: Source?
    let workspaceTitle: String
    let onBackToSpaces: () -> Void
    let onOpenAccountSettings: () -> Void
    let userInitial: String
    let onSourceOpened: (Source) -> Void
    let onAskSource: (Source) -> Void

    init(
        viewModel: SourceListViewModel,
        workspaceTitle: String,
        onBackToSpaces: @escaping () -> Void,
        onOpenAccountSettings: @escaping () -> Void,
        userInitial: String,
        onSourceOpened: @escaping (Source) -> Void,
        onAskSource: @escaping (Source) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.workspaceTitle = workspaceTitle
        self.onBackToSpaces = onBackToSpaces
        self.onOpenAccountSettings = onOpenAccountSettings
        self.userInitial = userInitial
        self.onSourceOpened = onSourceOpened
        self.onAskSource = onAskSource
    }

    var body: some View {
        ZStack {
            Color.folioCanvas.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                content
                    .frame(maxHeight: .infinity)
            }
        }
        .task {
            viewModel.send(.appeared)
        }
        .sheet(item: Binding(
            get: { viewModel.state.presentedSheet },
            set: { _ in
                viewModel.send(.dismissSheet)
            }
        )) { sheet in
            sheetContent(sheet)
        }
        .sheet(item: $actionSheetSource) { source in
            SourceActionSheet(
                title: source.title,
                onEdit: { viewModel.send(.ellipsisTapped(source)) },
                onDelete: { viewModel.send(.deleteTapped(source)) }
            )
        }
        .sheet(item: Binding(
            get: { viewModel.state.deleteConfirmationSource },
            set: { if $0 == nil { viewModel.send(.cancelDelete) } }
        )) { _ in
            ConfirmationBottomSheet(
                title: String(localized: "Delete source?"),
                message: String(localized: "This permanently removes the source and its retrieval data."),
                confirmTitle: String(localized: "Delete"),
                onCancel: { viewModel.send(.cancelDelete) },
                onConfirm: { viewModel.send(.deleteConfirmed) }
            )
        }
        .folioToast(message: Binding(
            get: { viewModel.state.toastMessage },
            set: { _ in viewModel.send(.dismissToast) }
        ))
    }

    @ViewBuilder
    private func sheetContent(_ sheet: SourceListViewModel.State.Sheet) -> some View {
        switch sheet {
        case .addSource:
            addSourceSheet
        case .editSource:
            EditSourceSheet(
                title: $viewModel.editTitle,
                author: $viewModel.editAuthor,
                content: $viewModel.editContent,
                sourceType: viewModel.state.editSource?.sourceType ?? .file,
                isEditing: viewModel.isEditing,
                errorMessage: viewModel.state.mutationError,
                maximumTitleLength: Source.maximumTitleLength,
                maximumAuthorLength: Source.maximumAuthorLength,
                maximumContentLength: Source.maximumContentLength,
                onCancel: {},
                onConfirm: { viewModel.send(.editConfirmed) }
            )
        case .processing(let source):
            SourceProcessingSheet(
                source: source,
                uploadSourceUseCase: viewModel.uploadSourceUseCase,
                onDismiss: {
                    viewModel.send(.dismissSheet)
                },
                onDeleted: { deletedSource in
                    viewModel.send(.sourceDeletedFromProcessing(deletedSource))
                },
                onStatusChanged: { updatedSource in
                    viewModel.send(.sourceStatusChanged(updatedSource))
                },
                onSourceOpened: onSourceOpened,
                onAskSource: onAskSource
            )
        case .failure(let source):
            SourceProcessingSheet(
                source: source,
                uploadSourceUseCase: viewModel.uploadSourceUseCase,
                onDismiss: {
                    viewModel.send(.dismissSheet)
                },
                onDeleted: { deletedSource in
                    viewModel.send(.sourceDeletedFromProcessing(deletedSource))
                },
                onStatusChanged: { updatedSource in
                    viewModel.send(.sourceStatusChanged(updatedSource))
                },
                onSourceOpened: onSourceOpened,
                onAskSource: onAskSource
            )
        case .sortOptions:
            SortOptionsSheet(
                title: String(localized: "Sort sources"),
                options: SourceSortOption.allCases,
                selectedValue: viewModel.state.sortOption,
                onSelect: { viewModel.send(.sortSelected($0)) }
            )
        }
    }

    private var addSourceSheet: some View {
        let vm = FolioAddSourceViewModel(
            uploadUseCase: viewModel.uploadSourceUseCase,
            spaceId: viewModel.spaceId
        )
        vm.onProcessingComplete = { [weak viewModel] _ in
            viewModel?.send(.sourceUploaded)
        }
        vm.onSourceCreated = { [weak viewModel] source in
            viewModel?.send(.sourceCreated(source))
        }
        return AnyView(FolioAddSourceSheet(
            viewModel: vm,
            onSourceOpened: { source in onSourceOpened(source) },
            onAskSource: { source in onAskSource(source) },
            onProcessingComplete: { _ in viewModel.send(.sourceUploaded) }
        ))
    }

    private var header: some View {
        VStack(spacing: 0) {
            FolioContentHeader(
                title: String(localized: "Sources"),
                subtitle: workspaceTitle,
                onBackToSpaces: onBackToSpaces,
                onPlusTapped: { viewModel.send(.addTapped) },
                searchPlaceholder: String(localized: "Search sources..."),
                searchText: Binding(
                    get: { viewModel.state.searchQuery },
                    set: { query in
                        Task { @MainActor in
                            viewModel.send(.searchQueryChanged(query))
                        }
                    }
                ),
                onClearSearch: { viewModel.send(.clearSearch) },
                onSortTapped: { viewModel.send(.sortTapped) },
                isSortActive: viewModel.state.sortOption != .recentlyAdded
            )

            HStack {
                ForEach(viewModel.state.filters) { filter in
                    Button {
                        Task { @MainActor in
                            viewModel.send(.selectFilter(filter))
                        }
                    } label: {
                        FolioPill(
                            title: filter.displayTitle,
                            isSelected: viewModel.state.selectedFilter == filter,
                            tint: filter.selectedTint,
                            fontSize: 13,
                            backgroundColor: filter.selectedBackgroundColor
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        viewModel.state.selectedFilter == filter ? .isSelected : []
                    )
                }
                Spacer()
            }
            .padding(.horizontal, FolioSpacing.xl)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(Color.folioCanvas)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.contentState {
        case .loading:
            loadingContent
        case .error(let message):
            SourceMessageState(
                title: message,
                systemImage: "wifi.slash",
                actionTitle: String(localized: "Retry"),
                action: { viewModel.send(.retry) },
                onRefresh: { await viewModel.refresh() }
            )
        case .empty:
            emptyContent
        case .noSearchResults:
            noSearchResultsContent
        case .loaded(let sources):
            sourceList(sources)
        }
    }

    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: FolioSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal, FolioSpacing.xl)
            .padding(.top, FolioSpacing.lg)
        }
    }

    private var skeletonCard: some View {
        HStack(alignment: .top, spacing: FolioSpacing.lg) {
            RoundedRectangle(cornerRadius: FolioRadius.md)
                .fill(Color.folioAccentLight.opacity(0.5))
                .frame(width: FolioSize.cardImage, height: FolioSize.cardImage)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: FolioRadius.xs)
                    .fill(Color.folioBorder)
                    .frame(height: FolioSize.skeletonBarHeight)
                RoundedRectangle(cornerRadius: FolioRadius.xs)
                    .fill(Color.folioBorderLight)
                    .frame(width: 160, height: FolioSize.skeletonBarSm)
            }

            Spacer()

            HStack(alignment: .center, spacing: 6) {
                RoundedRectangle(cornerRadius: FolioRadius.sm)
                    .fill(Color.folioSuccessLight.opacity(0.5))
                    .frame(width: 48, height: FolioSize.badgeHeight)
                RoundedRectangle(cornerRadius: FolioRadius.xs)
                    .fill(Color.folioBorderLight)
                    .frame(width: FolioSize.iconSm, height: FolioSize.iconSm)
            }
            .padding(.trailing, -4)
        }
        .padding(FolioSpacing.xl)
        .background(Color.folioCardBg)
        .overlay(
            RoundedRectangle(cornerRadius: FolioRadius.xl)
                .stroke(Color.folioBorderLight, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xl))
    }

    private var noSearchResultsContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    VStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.folioSurfaceStrong)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.folioInkSoft, lineWidth: 1)
                            )
                            .clipShape(Circle())

                        Spacer().frame(height: FolioSpacing.xl3)

                        Text(String(localized: "No results found"))
                            .font(.system(size: FolioFontSize.headline, weight: .semibold))
                            .foregroundStyle(Color.folioTextPrimary)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: FolioSpacing.sm)

                        Text(String(localized: "Try a different search term or clear your search."))
                            .font(.system(size: FolioFontSize.body, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                            .multilineTextAlignment(.center)
                    }

                    Spacer(minLength: 40)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, FolioSpacing.xl3)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    private var emptyContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    VStack(spacing: 0) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                            .frame(width: FolioSize.fieldHeightSm, height: FolioSize.fieldHeightSm)
                            .background(
                                Circle()
                                    .fill(Color.folioSurfaceStrong)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.folioLine, lineWidth: 1)
                            )
                            .clipShape(Circle())

                        Spacer().frame(height: FolioSpacing.xl3)

                        Text(String(localized: "No sources yet"))
                            .font(.system(size: FolioFontSize.headline, weight: .semibold))
                            .foregroundStyle(Color.folioTextPrimary)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: FolioSpacing.sm)

                        Text(String(localized: "Add a file, web article, or manual text source."))
                            .font(.system(size: FolioFontSize.body, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: FolioSpacing.xl4)

                        Button(action: { viewModel.send(.addTapped) }) {
                            Text(String(localized: "Add source"))
                                .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, FolioSpacing.xl3)
                                .padding(.vertical, 12)
                                .background(Color.folioOlive)
                                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, FolioSpacing.xl3)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    private func sourceList(_ sources: [Source]) -> some View {
        ScrollView {
            LazyVStack(spacing: FolioSpacing.md) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    SourceCard(source: source) {
                        handleCardTap(source)
                    } onEdit: {
                        actionSheetSource = source
                    } onDelete: {
                        viewModel.send(.deleteTapped(source))
                    }
                    .onAppear {
                        if index == sources.index(before: sources.endIndex) {
                            viewModel.send(.loadMore)
                        }
                    }
                }

                if viewModel.state.isLoadingNextPage {
                    ProgressView()
                        .tint(Color.folioOlive)
                        .padding(.vertical, FolioSpacing.lg)
                } else if let error = viewModel.state.paginationErrorMessage {
                    VStack(spacing: 6) {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.folioDanger)
                            .multilineTextAlignment(.center)
                        Button(String(localized: "Retry")) {
                            viewModel.send(.loadMore)
                        }
                        .tint(Color.folioOlive)
                    }
                    .padding(.vertical, FolioSpacing.lg)
                }
            }
            .padding(.horizontal, FolioSpacing.xl)
            .padding(.top, 0)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func handleCardTap(_ source: Source) {
        switch source.processingState {
        case .ready:
            onSourceOpened(source)
        case .failed:
            viewModel.send(.sourceTapped(source))
        case .added, .extractingText, .indexingEvidence:
            viewModel.send(.sourceTapped(source))
        }
    }
}

private struct SourceCard: View {
    let source: Source
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: FolioSpacing.lg) {
            fileBadge

            VStack(alignment: .leading, spacing: FolioSpacing.xs) {
                Text(source.title)
                    .font(.custom("CormorantGaramond-SemiBold", size: 18))
                    .foregroundStyle(Color.folioTextPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: FolioSpacing.xs) {
                    Text(source.author.isEmpty ? String(localized: "Unknown Author") : source.author)
                        .font(.system(size: FolioFontSize.caption2, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .lineLimit(1)

                    Text(String(localized: "·"))
                        .font(.system(size: FolioFontSize.caption2))
                        .foregroundStyle(Color.folioInkSoft)

                    Text(source.createdAt.addedRelativeLabel)
                        .font(.system(size: FolioFontSize.caption2, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: FolioSpacing.sm)

            HStack(alignment: .center, spacing: 6) {
                Text(statusTitle)
                    .font(.system(size: FolioFontSize.caption2, weight: .semibold))
                    .foregroundStyle(statusTitleColor)
                    .padding(.horizontal, FolioSpacing.md)
                    .frame(height: 35)
                    .background(statusBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm))

                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: FolioFontSize.body, weight: .semibold))
                        .foregroundStyle(Color.folioTextSecondary)
                        .rotationEffect(.degrees(90))
                        .frame(width: FolioSize.iconXl, height: FolioSpacing.xl6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: String(localized: "More options for %@"), source.title))
                .padding(.trailing, -4)
            }
        }
        .padding(FolioSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.folioCardBg)
        .overlay(
            RoundedRectangle(cornerRadius: FolioRadius.xl, style: .continuous)
                .stroke(Color.folioBorderLight, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xl, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var fileBadge: some View {
        Text(source.badgeText)
            .font(.system(size: FolioFontSize.caption2, weight: .semibold))
            .foregroundStyle(badgeTextColor)
            .frame(width: FolioSize.cardImage, height: FolioSize.cardImage)
            .background(badgeBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
    }

    private var badgeBackgroundColor: Color {
        switch source.sourceType {
        case .file: return Color.folioHomeTypeFileBackground
        case .web: return Color.folioHomeTypeWebBackground
        case .manual: return Color.folioHomeTypeTextBackground
        }
    }

    private var badgeTextColor: Color {
        switch source.sourceType {
        case .file: return Color.folioHomeTypeFileText
        case .web: return Color.folioHomeTypeWebText
        case .manual: return Color.folioHomeTypeTextText
        }
    }

    private var statusTitle: String {
        switch source.processingState {
        case .ready: return String(localized: "Ready")
        case .failed: return String(localized: "Failed")
        default: return String(localized: "Processing")
        }
    }

    private var statusTitleColor: Color {
        switch source.processingState {
        case .ready: return Color.folioSuccessText
        case .failed: return Color.folioDanger
        default: return Color.folioAmber
        }
    }

    private var statusBackgroundColor: Color {
        switch source.processingState {
        case .ready: return Color.folioSuccessLight
        case .failed: return Color.folioDanger.opacity(0.15)
        default: return Color.folioAmberBg
        }
    }
}

private struct SourceMessageState: View {
    let title: String
    var systemImage: String?
    let actionTitle: String
    let action: () -> Void
    var onRefresh: (() async -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: FolioSpacing.lg) {
                    Spacer(minLength: 20)
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: FolioFontSize.display))
                            .foregroundStyle(Color.folioInkSoft)
                    }
                    Text(title)
                        .font(.system(size: FolioFontSize.headline, weight: .semibold))
                        .foregroundStyle(Color.folioTextPrimary)
                        .multilineTextAlignment(.center)
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: FolioFontSize.body, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.folioOlive)
                    .padding(.horizontal, FolioSpacing.xl)
                    .padding(.vertical, FolioSpacing.sm)
                    Spacer(minLength: 20)
                }
                .padding(FolioSpacing.xl4)
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
            .refreshable {
                if let onRefresh {
                    await onRefresh()
                } else {
                    action()
                }
            }
        }
    }
}

extension FolioSourceFilter {
    var displayTitle: String {
        switch self {
        case .all: return "ALL"
        case .files: return "FILE"
        case .web: return "WEB"
        case .text: return "TEXT"
        }
    }
    var selectedTint: Color {
        switch self {
        case .all: return .folioHomeTypeFileText
        case .files: return .folioHomeTypeFileText
        case .web: return .folioHomeTypeWebText
        case .text: return .folioHomeTypeTextText
        }
    }

    var selectedBackgroundColor: Color {
        switch self {
        case .all: return .folioHomeTypeFileBackground
        case .files: return .folioHomeTypeFileBackground
        case .web: return .folioHomeTypeWebBackground
        case .text: return .folioHomeTypeTextBackground
        }
    }
}
    
extension SourceListViewModel {}
