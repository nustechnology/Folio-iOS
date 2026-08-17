import Combine
import Foundation

@MainActor
final class NoteListViewModel: ViewModelProtocol {
  enum Filter: CaseIterable, Hashable {
    case all
    case userCreated
    case savedAnswers

    var title: String {
      switch self {
      case .all:
        String(localized: "All")
      case .userCreated:
        String(localized: "User created")
      case .savedAnswers:
        String(localized: "Saved answers")
      }
    }

    var originQuery: String {
      switch self {
      case .all:
        "all"
      case .userCreated:
        NoteOriginType.userCreated.rawValue
      case .savedAnswers:
        NoteOriginType.savedAssistantAnswer.rawValue
      }
    }
  }

  enum Sheet: Identifiable, Equatable {
    case create
    case detail(Note)
    case edit(Note)
    case convert(Note)
    case processing(Source)
    case actions(NoteSummary)
    case sortOptions

    var id: String {
      switch self {
      case .create:
        "create"
      case .detail(let note):
        "detail-\(note.id)"
      case .edit(let note):
        "edit-\(note.id)"
      case .convert(let note):
        "convert-\(note.id)"
      case .processing(let source):
        "processing-\(source.id)"
      case .actions(let note):
        "actions-\(note.id)"
      case .sortOptions:
        "sort-options"
      }
    }
  }

  enum Action {
    case onAppear
    case refresh
    case retry
    case loadMore
    case searchChanged(String)
    case filterSelected(Filter)
    case sortTapped
    case sortSelected(NoteSortOption)
    case noteSelected(NoteSummary)
    case noteActionsRequested(NoteSummary)
    case viewRequested(NoteSummary)
    case editRequestedFromActionSheet(NoteSummary)
    case convertRequestedFromActionSheet(NoteSummary)
    case deleteRequestedFromActionSheet(NoteSummary)
    case editStarted(Note)
    case editSaved(Note)
    case createTitleChanged(String)
    case createContentChanged(String)
    case createSaveTapped
    case createCancelTapped
    case createDismissalAttempted
    case createDiscardConfirmed
    case createDiscardCancelled
    case deleteRequested(NoteSummary)
    case deleteConfirmed
    case dismissDeleteConfirmation
    case newTapped
    case convertTapped(NoteSummary)
    case convertConfirmed(String)
    case processingSourceDeleted
    case processingSourceStatusChanged
    case dismissSheet
    case sheetDismissed
    case dismissToast
    case editTitleChanged(String)
    case editContentChanged(String)
  }

  struct State: Equatable {
    var notes: [NoteSummary] = []
    var isLoading = false
    var isLoadingNextPage = false
    var errorMessage: String?
    var paginationErrorMessage: String?
    var searchQuery = ""
    var filter: Filter = .all
    var sortOption: NoteSortOption = .recentlyUpdated
    var pagination: NotePagination?
    var sheet: Sheet?
    var pendingDelete: NoteSummary?
    var isDeleting = false
    var toast: ToastMessage?
    var editTitle = ""
    var editContent = ""
    var isSaving = false
    var createTitle = ""
    var createContent = ""
    var createTitleError: String?
    var createContentError: String?
    var isCreating = false
    var isDiscardCreateDraftPresented = false
    var isConverting = false
  }

  @Published private(set) var state = State()

  let spaceId: String
  private let fetchNotes: any FetchNotesUseCaseProtocol
  private let fetchNote: any FetchNoteUseCaseProtocol
  private let createNote: (any CreateNoteUseCaseProtocol)?
  private let convertNoteToSource: (any ConvertNoteToSourceUseCaseProtocol)?
  let uploadSourceUseCase: (any UploadSourceUseCaseProtocol)?
  var onSourcesChanged: (() -> Void)?
  private let updateNote: any UpdateNoteUseCaseProtocol
  private let deleteNote: any DeleteNoteUseCaseProtocol
  private var didLoad = false
  private let searchSubject = PassthroughSubject<Void, Never>()
  private var cancellables = Set<AnyCancellable>()
  private var latestLoadRequestID = 0
  private var latestNoteRequestID = 0
  private var deletePendingSheetDismissal: NoteSummary?

  init(
    spaceId: String,
    fetchNotesUseCase: any FetchNotesUseCaseProtocol,
    fetchNoteUseCase: any FetchNoteUseCaseProtocol,
    updateNoteUseCase: any UpdateNoteUseCaseProtocol,
    deleteNoteUseCase: any DeleteNoteUseCaseProtocol,
    createNoteUseCase: (any CreateNoteUseCaseProtocol)? = nil,
    convertNoteToSourceUseCase: (any ConvertNoteToSourceUseCaseProtocol)? = nil,
    uploadSourceUseCase: (any UploadSourceUseCaseProtocol)? = nil
  ) {
    self.spaceId = spaceId
    fetchNotes = fetchNotesUseCase
    fetchNote = fetchNoteUseCase
    createNote = createNoteUseCase
    convertNoteToSource = convertNoteToSourceUseCase
    self.uploadSourceUseCase = uploadSourceUseCase
    updateNote = updateNoteUseCase
    deleteNote = deleteNoteUseCase

    searchSubject
      .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
      .sink { [weak self] in
        Task { await self?.loadPage(replace: true) }
      }
      .store(in: &cancellables)
  }

  func handle(_ action: Action) {
    switch action {
    case .onAppear, .refresh, .retry, .loadMore:
      handleLoadingAction(action)
    case .searchChanged, .filterSelected, .sortTapped, .sortSelected:
      handleFilteringAction(action)
    case .newTapped, .noteSelected, .noteActionsRequested, .viewRequested,
      .editRequestedFromActionSheet, .editStarted, .editSaved, .createTitleChanged,
      .createContentChanged, .createSaveTapped, .createCancelTapped, .createDismissalAttempted,
      .createDiscardConfirmed, .createDiscardCancelled:
      handleEditingAction(action)
    case .deleteRequested, .deleteRequestedFromActionSheet, .deleteConfirmed,
      .dismissDeleteConfirmation:
      handleDeletingAction(action)
    case .convertTapped, .convertRequestedFromActionSheet, .convertConfirmed:
      handleConversionAction(action)
    case .processingSourceDeleted:
      setSheet(nil)
      state.toast = .success(String(localized: "Source deleted"))
      onSourcesChanged?()
    case .processingSourceStatusChanged:
      onSourcesChanged?()
    case .dismissSheet, .sheetDismissed, .dismissToast, .editTitleChanged, .editContentChanged:
      handleDismissalOrDraftAction(action)
    }
  }

  func refreshNotes() async {
    await refresh()
  }
}

extension NoteListViewModel {
  private func handleLoadingAction(_ action: Action) {
    switch action {
    case .onAppear:
      load()
    case .refresh:
      Task { await refresh() }
    case .retry:
      retry()
    case .loadMore:
      loadMore()
    default:
      return
    }
  }

  private func handleFilteringAction(_ action: Action) {
    switch action {
    case .searchChanged(let query):
      setSearch(query)
    case .filterSelected(let filter):
      setFilter(filter)
    case .sortTapped:
      setSheet(.sortOptions)
    case .sortSelected(let option):
      setSort(option)
    default:
      return
    }
  }

  private func handleEditingAction(_ action: Action) {
    switch action {
    case .newTapped:
      state.createTitle = ""
      state.createContent = ""
      state.createTitleError = nil
      state.createContentError = nil
      state.isDiscardCreateDraftPresented = false
      setSheet(.create)
    case .noteSelected(let note):
      showDetail(note)
    case .noteActionsRequested(let note):
      setSheet(.actions(note))
    case .viewRequested(let note):
      setSheet(nil)
      showDetail(note)
    case .editRequestedFromActionSheet(let note):
      setSheet(nil)
      Task { await openEdit(note) }
    case .editStarted(let note):
      startEdit(note)
    case .editSaved(let note):
      saveEdit(note)
    case .createTitleChanged(let title):
      guard !state.isCreating else { return }
      state.createTitle = title
      state.createTitleError = title.count > NoteLimits.maximumTitleLength
        ? String(localized: "Title cannot exceed 150 characters")
        : nil
    case .createContentChanged(let content):
      guard !state.isCreating else { return }
      state.createContent = content
      state.createContentError = content.count > NoteLimits.maximumContentLength
        ? String(localized: "Content exceeds maximum length of 20,000 characters")
        : nil
    case .createSaveTapped:
      saveCreate()
    case .createCancelTapped:
      requestCreateDismissal()
    case .createDismissalAttempted:
      guard !state.isCreating else { return }
      requestCreateDismissal()
    case .createDiscardConfirmed:
      state.isDiscardCreateDraftPresented = false
      clearCreateDraft()
      setSheet(nil)
    case .createDiscardCancelled:
      state.isDiscardCreateDraftPresented = false
    default:
      return
    }
  }

  private func handleDeletingAction(_ action: Action) {
    switch action {
    case .deleteRequested(let note):
      requestDelete(note)
    case .deleteRequestedFromActionSheet(let note):
      requestDelete(note)
    case .deleteConfirmed:
      deletePending()
    case .dismissDeleteConfirmation:
      state.pendingDelete = nil
    default:
      return
    }
  }

  private func handleDismissalOrDraftAction(_ action: Action) {
    switch action {
    case .dismissSheet:
      guard !state.isConverting else { return }
      if state.sheet == .create {
        requestCreateDismissal()
      } else {
        setSheet(nil)
      }
    case .sheetDismissed:
      confirmDeferredDelete()
    case .dismissToast:
      state.toast = nil
    case .editTitleChanged(let title):
      state.editTitle = title
    case .editContentChanged(let content):
      state.editContent = content
    default:
      return
    }
  }

  private func handleConversionAction(_ action: Action) {
    switch action {
    case .convertTapped(let note):
      Task { await openConversion(note) }
    case .convertRequestedFromActionSheet(let note):
      setSheet(nil)
      Task { await openConversion(note) }
    case .convertConfirmed(let title):
      convertCurrentNote(title: title)
    default:
      return
    }
  }

  private func loadMore() {
    guard let page = state.pagination,
      page.page < page.totalPages,
      !state.isLoading,
      !state.isLoadingNextPage
    else {
      return
    }

    state.paginationErrorMessage = nil
    state.isLoadingNextPage = true
    Task { await loadPage(replace: false) }
  }

  private func load() {
    guard !didLoad else { return }

    didLoad = true
    Task { await loadPage(replace: true) }
  }

  private func refresh() async {
    await loadPage(replace: true)
  }

  private func retry() {
    Task { await loadPage(replace: true) }
  }

  private func setSearch(_ value: String) {
    guard value != state.searchQuery else { return }
    latestLoadRequestID += 1
    state.searchQuery = value
    searchSubject.send()
  }

  private func setFilter(_ value: Filter) {
    latestLoadRequestID += 1
    state.filter = value
    Task { await loadPage(replace: true) }
  }

  private func setSort(_ value: NoteSortOption) {
    guard value != state.sortOption else {
      setSheet(nil)
      return
    }
    latestLoadRequestID += 1
    state.sortOption = value
    setSheet(nil)
    Task { await loadPage(replace: true) }
  }

  private func showDetail(_ summary: NoteSummary) {
    Task { await openDetail(summary) }
  }

  private func openConversion(_ summary: NoteSummary) async {
    if let note = await fetchLatestNote(summary) {
      setSheet(.convert(note))
    }
  }

  private func convertCurrentNote(title: String) {
    guard case .convert(let note) = state.sheet, !state.isConverting else { return }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }
    guard let convertNoteToSource, uploadSourceUseCase != nil else {
      state.toast = .error(String(localized: "Source conversion is unavailable"))
      return
    }

    state.isConverting = true
    let limitedTitle = String(trimmedTitle.prefix(NoteLimits.maximumTitleLength))
    Task { await convert(note: note, title: limitedTitle, using: convertNoteToSource) }
  }

  private func startEdit(_ note: Note) {
    state.editTitle = note.title
    state.editContent = note.content
    setSheet(.edit(note))
  }

  private func openEdit(_ summary: NoteSummary) async {
    if let note = await fetchLatestNote(summary) {
      startEdit(note)
    }
  }

  private func saveEdit(_ note: Note) {
    let title = state.editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let content = state.editContent

    guard !title.isEmpty,
      !state.isSaving
    else {
      return
    }

    state.isSaving = true
    Task { await update(note, title: title, content: content) }
  }

  private func saveCreate() {
    guard let createNote, !state.isCreating else {
      if self.createNote == nil {
        state.toast = .error(String(localized: "Note creation is unavailable"))
      }
      return
    }

    validateCreateDraft()
    guard state.createTitleError == nil,
      state.createContentError == nil
    else { return }

    let title = state.createTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedTitle = title.isEmpty ? String(localized: "Untitled Note") : title
    state.isCreating = true
    Task { await create(note: createNote, title: resolvedTitle, content: state.createContent) }
  }

  private func validateCreateDraft() {
    let title = state.createTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let content = state.createContent.trimmingCharacters(in: .whitespacesAndNewlines)
    state.createTitleError = state.createTitle.count > NoteLimits.maximumTitleLength
      ? String(localized: "Title cannot exceed 150 characters")
      : nil
    if state.createContent.count > NoteLimits.maximumContentLength {
      state.createContentError = String(localized: "Content exceeds maximum length of 20,000 characters")
    } else if content.isEmpty {
      state.createContentError = String(localized: "Content cannot be empty")
    } else {
      state.createContentError = nil
    }
    if title.isEmpty { state.createTitleError = nil }
  }

  private func requestCreateDismissal() {
    guard hasCreateDraft else {
      clearCreateDraft()
      setSheet(nil)
      return
    }
    state.isDiscardCreateDraftPresented = true
  }

  var hasCreateDraft: Bool {
    !state.createTitle.isEmpty || !state.createContent.isEmpty
  }

  private func clearCreateDraft() {
    state.createTitle = ""
    state.createContent = ""
    state.createTitleError = nil
    state.createContentError = nil
    state.isCreating = false
  }

  private func confirmDelete(_ note: NoteSummary) {
    state.pendingDelete = note
  }

  private func requestDelete(_ note: NoteSummary) {
    guard state.sheet != nil else {
      confirmDelete(note)
      return
    }

    deletePendingSheetDismissal = note
    setSheet(nil)
  }

  private func confirmDeferredDelete() {
    guard let note = deletePendingSheetDismissal else { return }

    deletePendingSheetDismissal = nil
    confirmDelete(note)
  }

  private func deletePending() {
    guard let note = state.pendingDelete, !state.isDeleting else { return }

    state.isDeleting = true
    Task { await delete(note) }
  }

  private func loadPage(replace: Bool) async {
    latestLoadRequestID += 1
    let requestID = latestLoadRequestID

    if replace {
      state.isLoading = true
      state.errorMessage = nil
      state.paginationErrorMessage = nil
    } else {
      state.isLoadingNextPage = true
    }

    defer {
      if requestID == latestLoadRequestID {
        state.isLoading = false
        state.isLoadingNextPage = false
      }
    }

    do {
      let page = replace ? nil : (state.pagination?.page ?? 0) + 1
      let query = NoteListQuery(
        spaceId: spaceId,
        search: state.searchQuery.isEmpty ? nil : state.searchQuery,
        sort: state.sortOption.rawValue,
        origin: state.filter.originQuery,
        page: page,
        limit: state.pagination?.limit ?? 10
      )
      let result = try await fetchNotes.execute(query: query)

      guard requestID == latestLoadRequestID else { return }

      state.notes = replace ? result.notes : mergedNotes(with: result.notes)
      state.pagination = result.pagination
      Logger.debug("Loaded \(result.notes.count) notes for space \(spaceId)")
    } catch is CancellationError {
      return
    } catch let urlError as URLError where urlError.code == .cancelled {
      return
    } catch {
      guard requestID == latestLoadRequestID else { return }

      if replace {
        state.errorMessage = String(localized: "Failed to load notes. Please try again.")
      } else {
        state.paginationErrorMessage = String(localized: "Failed to load notes. Please try again.")
      }
      Logger.error("Failed to load notes for space \(spaceId): \(error)")
    }
  }

  private func mergedNotes(with newNotes: [NoteSummary]) -> [NoteSummary] {
    state.notes
      + newNotes.filter { newNote in
        !state.notes.contains { $0.id == newNote.id }
      }
  }

  private func openDetail(_ summary: NoteSummary) async {
    if let note = await fetchLatestNote(summary) {
      setSheet(.detail(note))
    }
  }

  private func setSheet(_ sheet: Sheet?) {
    latestNoteRequestID += 1
    state.sheet = sheet
  }

  private func fetchLatestNote(_ summary: NoteSummary) async -> Note? {
    latestNoteRequestID += 1
    let requestID = latestNoteRequestID

    do {
      let note = try await fetchNote.execute(spaceId: spaceId, noteId: summary.id)
      return requestID == latestNoteRequestID ? note : nil
    } catch {
      guard requestID == latestNoteRequestID else { return nil }
      state.toast = .error(String(localized: "Failed to fetch note. Please try again."))
      Logger.error("Failed to fetch note \(summary.id) in space \(spaceId): \(error)")
      return nil
    }
  }

  private func update(_ note: Note, title: String, content: String) async {
    defer { state.isSaving = false }

    do {
      _ = try await updateNote.execute(
        spaceId: spaceId,
        noteId: note.id,
        title: title,
        content: content
      )
      invalidateInFlightListLoads()
      setSheet(nil)
      state.toast = .success(String(localized: "Note updated successfully"))
      await loadPage(replace: true)
      Logger.debug("Note \(note.id) updated in space \(spaceId)")
    } catch {
      state.toast = .error(String(localized: "Failed to update note. Please try again."))
      Logger.error("Failed to update note \(note.id): \(error)")
    }
  }

  private func create(
    note: any CreateNoteUseCaseProtocol,
    title: String,
    content: String
  ) async {
    defer { state.isCreating = false }

    do {
      _ = try await note.execute(spaceId: spaceId, title: title, content: content)
      clearCreateDraft()
      setSheet(nil)
      state.toast = .success(String(localized: "Note saved"))
      await loadPage(replace: true)
    } catch {
      state.toast = .error(String(localized: "Failed to create note. Please try again."))
    }
  }

  private func convert(
    note: Note,
    title: String,
    using useCase: any ConvertNoteToSourceUseCaseProtocol
  ) async {
    defer { state.isConverting = false }

    do {
      let source = try await useCase.execute(spaceId: spaceId, noteId: note.id, title: title)
      setSheet(.processing(source))
      state.toast = .success(String(localized: "Source created"))
      onSourcesChanged?()
    } catch let error as NoteRepositoryError {
      state.toast = .error(error.errorDescription ?? String(localized: "Failed to create source. Please try again."))
      Logger.error("Failed to convert note \(note.id) to source: \(error)")
    } catch {
      state.toast = .error(String(localized: "Failed to create source. Please try again."))
      Logger.error("Failed to convert note \(note.id) to source: \(error)")
    }
  }

  private func delete(_ note: NoteSummary) async {
    defer { state.isDeleting = false }

    do {
      try await deleteNote.execute(spaceId: spaceId, noteId: note.id)
      invalidateInFlightListLoads()
      state.pendingDelete = nil
      state.toast = .success(String(localized: "Note deleted"))
      await loadPage(replace: true)
      Logger.debug("Note \(note.id) deleted from space \(spaceId)")
    } catch {
      state.toast = .error(String(localized: "Failed to delete note. Please try again."))
      Logger.error("Failed to delete note \(note.id): \(error)")
    }
  }

  private func invalidateInFlightListLoads() {
    latestLoadRequestID += 1
    state.isLoading = false
    state.isLoadingNextPage = false
  }
}
