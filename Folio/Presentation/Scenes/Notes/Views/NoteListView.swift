import SwiftUI

struct NoteListView: View {
    @ObservedObject var viewModel: NoteListViewModel
    let workspaceTitle: String
    let onBackToSpaces: () -> Void
    let onSourceOpened: (String) -> Void
    @State private var pendingSourceID: String?

    static func showsFullError(errorMessage: String?, notes: [NoteSummary]) -> Bool {
        errorMessage != nil && notes.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !viewModel.state.notes.isEmpty || !viewModel.state.searchQuery.isEmpty || viewModel.state.filter != .all {
                        filterBar
                    }
                    Spacer(minLength: 4)
                    content
                }
                .padding(FolioSpacing.xl2)
            }
            .refreshable { await viewModel.refreshNotes() }
            Spacer(minLength: 4)
        }
        .task { viewModel.handle(.onAppear) }
        .sheet(item: sheetBinding, onDismiss: {
            viewModel.handle(.sheetDismissed)
            openPendingSource()
        }) { sheet in
            sheetContent(sheet)
                .folioToast(message: toastBinding)
        }
        .deleteConfirmationOverlay(
            isPresented: viewModel.state.pendingDelete != nil,
            title: String(localized: "Are you sure you want to delete this note?"),
            message: String(localized: "This does not change the notebook or an existing source snapshot."),
            isDeleting: viewModel.state.isDeleting,
            onCancel: { viewModel.handle(.dismissDeleteConfirmation) },
            onDelete: { viewModel.handle(.deleteConfirmed) }
        )
        .folioToast(message: toastBinding)
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.state.searchQuery },
            set: { viewModel.handle(.searchChanged($0)) }
        )
    }

    private var sheetBinding: Binding<NoteListViewModel.Sheet?> {
        Binding(
            get: { viewModel.state.sheet },
            set: { _ in viewModel.handle(.dismissSheet) }
        )
    }

    private var toastBinding: Binding<ToastMessage?> {
        Binding(
            get: { viewModel.state.toast },
            set: { _ in viewModel.handle(.dismissToast) }
        )
    }

    private var filterBar: some View {
        HStack {
            ForEach(NoteListViewModel.Filter.allCases, id: \.self) { filter in
                Button {
                    viewModel.handle(.filterSelected(filter))
                } label: {
                    FolioPill(
                        title: filter.title,
                        isSelected: viewModel.state.filter == filter,
                        tint: .folioInk,
                        fontSize: 13,
                        backgroundColor: .folioHomeTypeFileBackground
                    )
                }
            }
            Spacer()
        }
    }

    private var searchHeader: some View {
        FolioSearchHeader(
            title: String(localized: "Notes"),
            subtitle: workspaceTitle,
            searchPlaceholder: String(localized: "Search notes"),
            searchText: searchBinding,
            onClearSearch: { viewModel.handle(.searchChanged("")) },
            onSortTapped: { viewModel.handle(.sortTapped) },
            isSortActive: viewModel.state.sortOption != .recentlyUpdated,
            leadingAction: AnyView(
                Button(action: onBackToSpaces) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white)
                }
            ),
            trailingActions: [
                AnyView(
                    Button {
                        viewModel.handle(.newTapped)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                    }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .accessibilityLabel(String(localized: "Add note"))
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                )
            ],
            showsSort: true
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.isLoading && viewModel.state.notes.isEmpty {
            LazyVStack(alignment: .leading, spacing: FolioSpacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    NoteRowSkeleton()
                }
            }
        } else if Self.showsFullError(errorMessage: viewModel.state.errorMessage, notes: viewModel.state.notes),
                  let error = viewModel.state.errorMessage {
            ErrorView(message: error, retryAction: { viewModel.handle(.retry) })
        } else if viewModel.state.notes.isEmpty && viewModel.state.searchQuery.isEmpty && viewModel.state.filter == .all {
            VStack(spacing: FolioSpacing.xl) {
                Image(systemName: "doc.fill")
                    .font(.system(size: FolioFontSize.subheadline, weight: .medium))
                    .foregroundStyle(Color.folioInkSoft)
                    .frame(width: FolioSize.fieldHeightSm, height: FolioSize.fieldHeightSm)
                    .background(Color.folioSurfaceStrong)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.folioLine.opacity(0.65), lineWidth: 1)
                    )

                VStack(spacing: FolioSpacing.sm) {
                    Text(String(localized: "No notes yet"))
                        .font(.system(size: FolioFontSize.headline, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                    Text(String(localized: "Create a note or save an answer from the chat."))
                        .font(.system(size: FolioFontSize.body, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .multilineTextAlignment(.center)
                }

                Button {
                    viewModel.handle(.newTapped)
                } label: {
                    Text(String(localized: "Add note"))
                        .font(.system(size: FolioFontSize.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 38)
                        .background(Color.folioOlive)
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical)
        } else if viewModel.state.notes.isEmpty {
            VStack(spacing: FolioSpacing.xl) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: FolioFontSize.subheadline, weight: .medium))
                    .foregroundStyle(Color.folioInkSoft)
                    .frame(width: FolioSize.fieldHeightSm, height: FolioSize.fieldHeightSm)
                    .background(Color.folioSurfaceStrong)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.folioLine.opacity(0.65), lineWidth: 1)
                    )

                VStack(spacing: FolioSpacing.sm) {
                    Text(emptyFilterTitle)
                        .font(.system(size: FolioFontSize.headline, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        } else {
            LazyVStack(alignment: .leading, spacing: FolioSpacing.sm) {
                if let error = viewModel.state.errorMessage {
                    VStack(spacing: 6) {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.folioDanger)
                            .multilineTextAlignment(.center)
                        Button(String(localized: "Retry")) {
                            viewModel.handle(.retry)
                        }
                        .tint(Color.folioOlive)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, FolioSpacing.sm)
                }

                ForEach(Array(viewModel.state.notes.enumerated()), id: \.element.id) { index, note in
                    NoteRow(
                        note: note,
                        onOpen: { viewModel.handle(.noteSelected(note)) },
                        onActions: { viewModel.handle(.noteActionsRequested(note)) }
                    )
                    .onAppear {
                        if index == viewModel.state.notes.index(before: viewModel.state.notes.endIndex) {
                            viewModel.handle(.loadMore)
                        }
                    }
                }

                if viewModel.state.isLoadingNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FolioSpacing.lg)
                } else if let error = viewModel.state.paginationErrorMessage {
                    VStack(spacing: 6) {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.folioDanger)
                            .multilineTextAlignment(.center)
                        Button(String(localized: "Retry")) {
                            viewModel.handle(.loadMore)
                        }
                        .tint(Color.folioOlive)
                    }
                    .padding(.vertical, FolioSpacing.lg)
                }
            }
        }
    }

    private var emptyFilterTitle: String {
        viewModel.state.searchQuery.isEmpty
        ? String(localized: "No notes found")
        : String(localized: "No notes found matching \"\(viewModel.state.searchQuery)\"")
    }

    @ViewBuilder
    private func sheetContent(_ sheet: NoteListViewModel.Sheet) -> some View {
        switch sheet {
        case .create:
            NoteCreateView(viewModel: viewModel)
        case .actions(let note):
            NoteActionSheet(
                note: note,
                onView: { viewModel.handle(.viewRequested(note)) },
                onEdit: { viewModel.handle(.editRequestedFromActionSheet(note)) },
                onConvert: { viewModel.handle(.convertRequestedFromActionSheet(note)) },
                onDelete: { viewModel.handle(.deleteRequestedFromActionSheet(note)) }
            )
        case .detail(let note):
            NoteDetailView(
                note: note,
                onEdit: { viewModel.handle(.editStarted(note)) },
                onConvert: { viewModel.handle(.convertTapped(note.summary)) },
                onOpenSource: { sourceID in
                    pendingSourceID = sourceID
                    viewModel.handle(.dismissSheet)
                }
            )
        case .edit(let note):
            NoteEditView(note: note, viewModel: viewModel)
        case .convert(let note):
            ConvertToSourceView(
                note: note,
                isCreating: viewModel.state.isConverting,
                onCreate: { title in viewModel.handle(.convertConfirmed(title)) }
            )
        case .processing(let source):
            if let uploadSourceUseCase = viewModel.uploadSourceUseCase {
                SourceProcessingSheet(
                    source: source,
                    uploadSourceUseCase: uploadSourceUseCase,
                    onDismiss: { viewModel.handle(.dismissSheet) },
                    onDeleted: { _ in viewModel.handle(.processingSourceDeleted) },
                    onStatusChanged: { _ in viewModel.handle(.processingSourceStatusChanged) },
                    onSourceOpened: { source in onSourceOpened(source.id) }
                )
            }
        case .sortOptions:
            SortOptionsSheet<NoteSortOption>(
                title: String(localized: "Sort notes"),
                options: NoteSortOption.allCases,
                selectedValue: viewModel.state.sortOption,
                onSelect: { viewModel.handle(.sortSelected($0)) }
            )
        }
    }

    private func openPendingSource() {
        guard let sourceID = pendingSourceID else { return }
        pendingSourceID = nil
        onSourceOpened(sourceID)
    }
}

private struct NoteRowSkeleton: View {
    var body: some View {
        FolioCard(
            content: HStack(alignment: .top, spacing: FolioSpacing.sm) {
                HStack(alignment: .top, spacing: FolioSpacing.lg) {
                    Color.folioBorderLight.opacity(0.35)
                        .frame(width: FolioSize.chipHeight, height: FolioSize.chipHeight)
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Color.folioBorderLight.opacity(0.35)
                            .frame(width: 160, height: FolioSpacing.xl)
                            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous))
                        Color.folioBorderLight.opacity(0.35)
                            .frame(height: FolioSpacing.lg)
                            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous))
                        Color.folioBorderLight.opacity(0.35)
                            .frame(width: 120, height: FolioSpacing.lg)
                            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous))

                        Spacer(minLength: FolioSpacing.xs)

                        HStack(alignment: .center, spacing: FolioSpacing.sm) {
                            HStack(spacing: 6) {
                                Color.folioBorderLight.opacity(0.35)
                                    .frame(width: 56, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                Color.folioBorderLight.opacity(0.6)
                                    .frame(width: 36, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            Spacer(minLength: FolioSpacing.xs)
                            Color.folioBorderLight.opacity(0.35)
                                .frame(width: 52, height: 11)
                                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Color.folioBorderLight.opacity(0.6)
                    .frame(width: FolioSize.iconSm, height: FolioSize.iconSm)
                    .clipShape(Circle())
                    .padding(.top, FolioSpacing.sm)
            }
        )
    }
}
