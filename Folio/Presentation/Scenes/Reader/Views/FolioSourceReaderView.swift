import SwiftUI

struct FolioSourceReaderView: View {
    @StateObject private var viewModel: SourceReaderViewModel
    @State private var webContentHeight: CGFloat = 300
    @State private var showSourceActionSheet = false
    
    private let passageID: String?
    private let onBack: () -> Void
    private var onAskSource: ((Source) -> Void)?
    private var onDeleted: ((Source) -> Void)?
    
    init(
        sourceID: String,
        fetchSourceDetailUseCase: any FetchSourceDetailUseCaseProtocol,
        updateSourceUseCase: any UpdateSourceUseCaseProtocol,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol,
        fetchSourcePreviewUseCase: any FetchSourcePreviewUseCaseProtocol,
        passageID: String? = nil,
        onBack: @escaping () -> Void,
        onAskSource: ((Source) -> Void)? = nil,
        onDeleted: ((Source) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: SourceReaderViewModel(
            sourceID: sourceID,
            fetchSourceDetailUseCase: fetchSourceDetailUseCase,
            updateSourceUseCase: updateSourceUseCase,
            uploadSourceUseCase: uploadSourceUseCase,
            fetchSourcePreviewUseCase: fetchSourcePreviewUseCase,
            onAskSource: onAskSource,
            onDeleted: onDeleted
        ))
        self.passageID = passageID
        self.onBack = onBack
        self.onAskSource = onAskSource
        self.onDeleted = onDeleted
    }
    
    var body: some View {
        ZStack {
            Color.folioCanvas.ignoresSafeArea()
            if let source = viewModel.source {
                VStack(spacing: 0) {
                    SourceReaderHeader(
                        source: source,
                        onBack: onBack,
                        headerTrailing: { AnyView(menuButton) },
                        infoTrailing: { AnyView(HStack(spacing: 8) {
                            askSourceButton
                            if source.sourceType != .manual {
                                openOriginalButton
                            }
                        }) }
                    )
                    scrollableContentCard
                }
            } else if viewModel.state.errorMessage == nil {
                FolioSourceReaderSkeletonView(onBack: onBack)
            } else {
                VStack(spacing: 0) {
                    FolioSourceReaderSkeletonHeader(onBack: onBack)
                    scrollableContentCard
                }
            }
        }
        .task { viewModel.send(.appeared) }
        .sheet(item: sheetBinding) { sheet in
            switch sheet {
            case .edit:
                EditSourceSheet(
                    title: Binding(
                        get: { viewModel.state.editTitle },
                        set: { viewModel.send(.editTitleChanged($0)) }
                    ),
                    author: Binding(
                        get: { viewModel.state.editAuthor },
                        set: { viewModel.send(.editAuthorChanged($0)) }
                    ),
                    content: Binding(
                        get: { viewModel.state.editContent },
                        set: { viewModel.send(.editContentChanged($0)) }
                    ),
                    sourceType: viewModel.source?.sourceType ?? .file,
                    isEditing: viewModel.state.isEditing,
                    errorMessage: viewModel.state.editError,
                    maximumTitleLength: Source.maximumTitleLength,
                    maximumAuthorLength: Source.maximumAuthorLength,
                    maximumContentLength: Source.maximumContentLength,
                    onCancel: { viewModel.send(.cancelEdit) },
                    onConfirm: { viewModel.send(.editConfirmed) }
                )
            case .share(let url):
                FolioShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showSourceActionSheet) {
            SourceActionSheet(
                title: viewModel.source?.title ?? "",
                onEdit: { viewModel.send(.editTapped) },
                onDelete: { viewModel.send(.deleteTapped) }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.state.showOpenOriginalSheet },
            set: { if !$0 { viewModel.send(.dismissOpenOriginalSheet) } }
        )) {
            OpenOriginalBottomSheet(
                fileName: viewModel.source?.sourceType == .web ? (viewModel.source?.sourceUrl ?? "") : (viewModel.source?.fileName ?? ""),
                sourceType: viewModel.source?.sourceType ?? .file,
                onCancel: { viewModel.send(.dismissOpenOriginalSheet) },
                onOpen: { viewModel.send(.openOriginalConfirmed) }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.state.showDeleteConfirmation },
            set: { if !$0 { viewModel.send(.cancelDelete) } }
        )) {
            ConfirmationBottomSheet(
                title: String(localized: "Delete this source?"),
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
    
    // MARK: - Header
    
    private var menuButton: some View {
        Button {
            showSourceActionSheet = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .rotationEffect(.degrees(90))
                .foregroundStyle(Color.folioInk)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.folioFieldBorder, lineWidth: 0.5)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "More options"))
    }
    
    // MARK: - Action buttons
    
    private var askSourceButton: some View {
        Button {
            viewModel.send(.askThisSource)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(localized: "Ask source"))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.folioHomeHeader)
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Ask this source"))
    }
    
    private var openOriginalButton: some View {
        Button {
            viewModel.send(.openOriginalTapped)
        } label: {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.folioInk)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.folioFieldBorder, lineWidth: 0.5)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Open original"))
    }
    
    // MARK: - Content

    private var scrollableContentCard: some View {
        ScrollView {
            contentCard
        }
        .background(Color.folioSurfaceStrong)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 16
        ))
        .padding(.horizontal, 18)
        .ignoresSafeArea(edges: .bottom)
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = viewModel.state.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.folioDanger)
                    Text(error)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                        .lineLimit(2)
                    Spacer()
                    Button(String(localized: "Retry")) {
                        viewModel.send(.retry)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioOlive)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.folioDanger.opacity(0.08))
            }
            
            if let source = viewModel.source {
                ReaderWebContentView(
                    html: SourceHTMLBuilder.fullHTML(for: source),
                    passageID: passageID,
                    onHeightChange: { height in webContentHeight = height }
                )
                .frame(maxWidth: .infinity)
                .frame(height: max(webContentHeight, 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }
    
    // MARK: - Sheets
    
    private enum ReaderSheet: Identifiable {
        case edit
        case share(URL)
        
        var id: String {
            switch self {
            case .edit: return "edit"
            case .share: return "share"
            }
        }
    }
    
    private var activeSheet: ReaderSheet? {
        if viewModel.state.showEditSheet { return .edit }
        if viewModel.state.showShareSheet, let url = viewModel.state.previewUrl { return .share(url) }
        return nil
    }
    
    private var sheetBinding: Binding<ReaderSheet?> {
        Binding(
            get: { activeSheet },
            set: { newValue in
                if newValue == nil {
                    viewModel.send(.cancelEdit)
                    viewModel.send(.cancelDelete)
                    viewModel.send(.dismissShareSheet)
                }
            }
        )
    }
    
    // MARK: - Sheets
}


#Preview {
    FolioSourceReaderView(
        sourceID: "preview-source",
        fetchSourceDetailUseCase: PreviewFetchSourceDetailUseCase(),
        updateSourceUseCase: PreviewUpdateSourceUseCase(),
        uploadSourceUseCase: PreviewUploadSourceUseCase(),
        fetchSourcePreviewUseCase: PreviewFetchSourcePreviewUseCase(),
        onBack: {},
        onAskSource: { _ in },
        onDeleted: { _ in }
    )
}

private struct PreviewFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source {
        Source(
            id: id,
            researchSpaceId: "space",
            sourceType: .file,
            title: "Alan Turing: Computing Machinery",
            author: "Alan Turing",
            sourceUrl: "",
            fileName: "turing.pdf",
            fileSize: 0,
            fileType: "application/pdf",
            pageCount: 14,
            characterCount: 0,
            content: "",
            structuredContent: nil,
            processingState: .ready,
            processingError: "",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private struct PreviewUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String, content: String?) async throws -> Source {
        Source(id: id, researchSpaceId: "", sourceType: .file, title: title, author: author, sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0, characterCount: 0, content: content ?? "", structuredContent: nil, processingState: .ready, processingError: "", createdAt: Date(), updatedAt: Date())
    }
}

private struct PreviewUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func deleteSource(id: String) async throws {}
    func retrySource(id: String) async throws -> Source { throw CancellationError() }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview {
        SourcePreview(url: "https://example.com/preview.pdf")
    }
}
