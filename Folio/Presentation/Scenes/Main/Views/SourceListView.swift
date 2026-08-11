import SwiftUI

struct SourceListView: View {
    @StateObject private var viewModel: SourceListViewModel
    let workspaceTitle: String
    let onBackToSpaces: () -> Void
    let onOpenAccountSettings: () -> Void
    let userInitial: String
    let onSourceOpened: (Source) -> Void

    init(
        viewModel: SourceListViewModel,
        workspaceTitle: String,
        onBackToSpaces: @escaping () -> Void,
        onOpenAccountSettings: @escaping () -> Void,
        userInitial: String,
        onSourceOpened: @escaping (Source) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.workspaceTitle = workspaceTitle
        self.onBackToSpaces = onBackToSpaces
        self.onOpenAccountSettings = onOpenAccountSettings
        self.userInitial = userInitial
        self.onSourceOpened = onSourceOpened
    }

    var body: some View {
        ZStack {
            Color.folioCanvas.ignoresSafeArea()
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    content.frame(height: geometry.size.height - geometry.safeAreaInsets.top)
                }
            }
        }
        .task { viewModel.send(.appeared) }
        .sheet(item: Binding(
            get: { viewModel.state.presentedSheet },
            set: { _ in viewModel.send(.dismissSheet) }
        )) { sheet in
            sheetContent(sheet)
        }
        .alert(
            String(localized: "Delete source?"),
            isPresented: Binding(
                get: { viewModel.state.deleteConfirmationSource != nil },
                set: { if !$0 { viewModel.send(.cancelDelete) } }
            )
        ) {
            Button(String(localized: "Cancel"), role: .cancel) { viewModel.send(.cancelDelete) }
            Button(String(localized: "Delete"), role: .destructive) { viewModel.send(.deleteConfirmed) }
        } message: {
            Text(String(localized: "This permanently removes the source and its retrieval data."))
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
            FolioAddSourceSheet(
                uploadUseCase: viewModel.uploadSourceUseCase,
                spaceId: viewModel.spaceId,
                onSourceOpened: { source in
                    viewModel.send(.sourceUploaded)
                    onSourceOpened(source)
                },
                onAskSource: { _ in }
            )
        case .editSource:
            EditSourceSheet(viewModel: viewModel)
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
                onSourceOpened: onSourceOpened
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
                onSourceOpened: onSourceOpened
            )
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            FolioTopBar(
                title: String(localized: "Sources"),
                subtitle: workspaceTitle,
                leading: AnyView(
                    Button(action: onBackToSpaces) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: FolioFontSize.bodySmall, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: FolioSize.iconLg, height: FolioSize.iconLg)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Back to My Spaces"))
                ),
                trailing: [
                    AnyView(
                        Button(action: { viewModel.send(.addTapped) }) {
                            Image(systemName: "plus")
                                .font(.system(size: FolioFontSize.body, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Add source"))
                    )
                ]
            )
            .padding(.top, FolioSpacing.xs)

            VStack(spacing: FolioSpacing.lg) {
                HStack {
                    Text(String(localized: "Sources"))
                        .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                    Text("\(viewModel.state.totalCount) total")
                        .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                    Spacer()
                }
                .padding(.horizontal, FolioSpacing.xl)
                .padding(.top, FolioSpacing.lg)

                FolioSearchField(
                    placeholder: String(localized: "Search sources..."),
                    text: Binding(
                        get: { viewModel.state.searchQuery },
                        set: { viewModel.send(.searchQueryChanged($0)) }
                    )
                )
                .padding(.horizontal, FolioSpacing.xl)

                HStack(spacing: FolioSpacing.md) {
                    ForEach(viewModel.state.filters) { filter in
                        Button {
                            viewModel.send(.selectFilter(filter))
                        } label: {
                            Text(filter.displayTitle)
                                .font(.system(size: FolioFontSize.body, weight: .medium))
                                .foregroundStyle(Color.folioTextSecondary)
                                .padding(.horizontal, FolioSpacing.xl2)
                                .frame(height: FolioSize.chipHeight)
                                .background(
                                    viewModel.state.selectedFilter == filter
                                        ? Color.folioAccentBg
                                        : Color.folioCanvas
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: FolioRadius.chip)
                                        .stroke(
                                            viewModel.state.selectedFilter == filter
                                                ? Color.folioAccentBorder
                                                : Color.folioBorder,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.chip))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, FolioSpacing.xl)
            }
            .padding(.bottom, FolioSpacing.lg)
            .background(.white)
        }
        .background(Color.folioOlive)
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
                action: { viewModel.send(.retry) }
            )
        case .empty:
            emptyContent
        case .noSearchResults(let query):
            SourceMessageState(
                title: String(localized: "No sources found matching \"\(query)\""),
                systemImage: "magnifyingglass",
                actionTitle: String(localized: "Clear search"),
                action: { viewModel.send(.clearSearch) }
            )
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

    private var emptyContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            VStack(spacing: FolioSpacing.xl3) {
                FolioEmptyStateView(
                    title: String(localized: "No sources yet"),
                    subtitle: String(localized: "Add your first source to start building your research archive."),
                    iconName: "doc.text"
                )

                Button(action: { viewModel.send(.addTapped) }) {
                    Text(String(localized: "Add Source"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.folioOlive)
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, FolioSpacing.xl)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sourceList(_ sources: [Source]) -> some View {
        ScrollView {
            LazyVStack(spacing: FolioSpacing.md) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    SourceCard(source: source) {
                        handleCardTap(source)
                    } onEdit: {
                        viewModel.send(.ellipsisTapped(source))
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
            .padding(.top, FolioSpacing.lg)
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
                    .font(.system(size: FolioFontSize.headline, weight: .semibold))
                    .foregroundStyle(Color.folioTextPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: FolioSpacing.xs) {
                    Text(source.author.isEmpty ? String(localized: "Unknown Author") : source.author)
                        .font(.system(size: FolioFontSize.caption2, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .lineLimit(1)

                    Text("·")
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
                    .frame(height: FolioSize.badgeHeight)
                    .background(statusBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm))

                Menu {
                    Button(String(localized: "Edit"), action: onEdit)
                    Button(String(localized: "Delete"), role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: FolioFontSize.body, weight: .semibold))
                        .foregroundStyle(Color.folioTextSecondary)
                        .rotationEffect(.degrees(90))
                        .frame(width: FolioSize.iconXl, height: FolioSpacing.xl6)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "More options for \(source.title)"))
                .padding(.trailing, -4)
            }
        }
        .padding(FolioSpacing.xl)
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
            .foregroundStyle(Color.folioAccent)
            .frame(width: FolioSize.cardImage, height: FolioSize.cardImage)
            .background(Color.folioAccentLight)
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
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

    var body: some View {
        VStack(spacing: FolioSpacing.lg) {
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
        }
        .padding(FolioSpacing.xl4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EditSourceSheet: View {
    @ObservedObject var viewModel: SourceListViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case author
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FolioSpacing.xl) {
            Text(String(localized: "Edit Source"))
                .font(.system(size: FolioFontSize.heading, weight: .regular, design: .serif))
                .foregroundStyle(Color.folioTextPrimary)
                .padding(.top, FolioSpacing.xl5)
                .padding(.bottom, FolioSpacing.sm)

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Title"))
                    .font(.system(size: FolioFontSize.body, weight: .medium))
                    .foregroundStyle(Color.folioInkSoft)
                TextField(String(localized: "Title"), text: $viewModel.editTitle)
                    .font(.system(size: FolioFontSize.bodyLarge))
                    .padding(.horizontal, FolioSpacing.xl)
                    .frame(height: FolioSize.fieldHeightXs)
                    .background(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.md)
                            .stroke(Color.folioBorderLight, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                    .focused($focusedField, equals: .title)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Author / Publisher"))
                    .font(.system(size: FolioFontSize.body, weight: .medium))
                    .foregroundStyle(Color.folioInkSoft)
                TextField(String(localized: "Author"), text: $viewModel.editAuthor)
                    .font(.system(size: FolioFontSize.bodyLarge))
                    .padding(.horizontal, FolioSpacing.xl)
                    .frame(height: FolioSize.fieldHeightXs)
                    .background(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.md)
                            .stroke(Color.folioBorderLight, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                    .focused($focusedField, equals: .author)
            }

            if let error = viewModel.state.mutationError {
                Text(error)
                    .font(.system(size: FolioFontSize.small))
                    .foregroundStyle(Color.folioDanger)
            }

            HStack(spacing: FolioSpacing.lg) {
                Button {
                    focusedField = nil
                    dismiss()
                } label: {
                    Text(String(localized: "Cancel"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .medium))
                        .foregroundStyle(Color.folioTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.folioCanvas)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md)
                                .stroke(Color.folioBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                        .contentShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    focusedField = nil
                    viewModel.send(.editConfirmed)
                } label: {
                    Text(String(localized: "Save"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.folioOlive)
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                        .contentShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isEditing)
            }
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.bottom, FolioSpacing.xl4)
        .padding(.top, FolioSpacing.lg)
        .frame(maxWidth: .infinity)
        .presentationBackground(Color.white)
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.visible)
    }
}

extension FolioSourceFilter {
    var displayTitle: String {
        switch self {
        case .all: return String(localized: "All")
        case .files: return "FILE"
        case .web: return "WEB"
        case .text: return "TEXT"
        }
    }
}

extension SourceListViewModel {}
