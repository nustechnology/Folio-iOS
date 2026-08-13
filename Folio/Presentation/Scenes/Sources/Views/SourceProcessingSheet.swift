import SwiftUI

struct SourceProcessingSheet: View {
    @StateObject private var viewModel: SourceProcessingViewModel

    private let onDismiss: () -> Void
    private let onDeleted: (Source) -> Void
    private let onStatusChanged: (Source) -> Void
    private let onSourceOpened: ((Source) -> Void)?
    private let onAskSource: ((Source) -> Void)?

    init(
        source: Source,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol,
        onDismiss: @escaping () -> Void,
        onDeleted: @escaping (Source) -> Void,
        onStatusChanged: @escaping (Source) -> Void,
        onSourceOpened: ((Source) -> Void)? = nil,
        onAskSource: ((Source) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: SourceProcessingViewModel(
            source: source,
            uploadSourceUseCase: uploadSourceUseCase,
            onBack: onDismiss,
            onDeleted: onDeleted,
            onStatusChanged: onStatusChanged
        ))
        self.onDismiss = onDismiss
        self.onDeleted = onDeleted
        self.onStatusChanged = onStatusChanged
        self.onSourceOpened = onSourceOpened
        self.onAskSource = onAskSource
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, FolioSpacing.lg)

            SourceReaderHeader(
                source: viewModel.state.source,
                headerTrailing: { AnyView(closeButton) }
            )

            Divider().background(Color.folioLine)

            ScrollView {
                VStack(spacing: FolioSpacing.xl3) {
                    processingStatusCard

                    if viewModel.state.isProcessingFailed {
                        failureActions
                    }
                }
                .padding(FolioSpacing.xl)
            }
        }
        .background(Color.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .alert(
            String(localized: "Are you sure you want to delete this source?"),
            isPresented: Binding(
                get: { viewModel.state.showDeleteConfirmation },
                set: { if !$0 { viewModel.send(.cancelDelete) } }
            )
        ) {
            Button(String(localized: "Cancel"), role: .cancel) { viewModel.send(.cancelDelete) }
            Button(String(localized: "Delete"), role: .destructive) { viewModel.send(.deleteConfirmed) }
        }
        .onChange(of: viewModel.state.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { onDismiss() }
        }
    }

    private var closeButton: some View {
        Button {
            viewModel.send(.back)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: FolioFontSize.body, weight: .medium))
                .foregroundStyle(Color.folioInkMuted)
                .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                .background(Color.folioSurface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Close"))
    }

    // MARK: - Status card

    private var processingStatusCard: some View {
        VStack(spacing: FolioSpacing.xl3) {
            stageList

            if !viewModel.state.isProcessingFailed {
                progressSection
            }

            if viewModel.state.isProcessingFailed {
                failureBanner
            }

            if viewModel.state.isProcessingComplete {
                completionActions
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FolioSpacing.lg)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: FolioRadius.xl, style: .continuous)
                .stroke(Color.folioBorderLight, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xl, style: .continuous))
    }

    private var stageList: some View {
        VStack(spacing: FolioSpacing.md) {
            ForEach(Array(viewModel.state.processingStages.enumerated()), id: \.offset) { _, item in
                HStack(spacing: FolioSpacing.md) {
                    stageIcon(for: item.status)
                        .frame(width: FolioSize.iconMd, height: FolioSize.iconMd)

                    Text(item.stage.title)
                        .font(.system(size: FolioFontSize.bodyLarge, weight: item.status == .active ? .semibold : .regular))
                        .foregroundStyle(stageTextColor(for: item.status))

                    Spacer()
                }
            }
        }
    }

    private func stageIcon(for status: SourceProcessingViewModel.StageStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Circle()
                    .stroke(Color.folioLine, lineWidth: 2)
                    .frame(width: FolioSize.iconMd, height: FolioSize.iconMd)
            case .active:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.folioGold)
                    .scaleEffect(0.8)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: FolioSize.iconMd))
                    .foregroundStyle(Color.folioSuccessStrong)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: FolioSize.iconMd))
                    .foregroundStyle(Color.folioDanger)
            }
        }
    }

    private func stageTextColor(for status: SourceProcessingViewModel.StageStatus) -> Color {
        switch status {
        case .pending: return Color.folioInkSoft
        case .active: return Color.folioInk
        case .completed: return Color.folioInk
        case .failed: return Color.folioDanger
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: FolioSpacing.sm) {
            HStack {
                Text(viewModel.state.isProcessingComplete ? String(localized: "Ready") : "\(Int(viewModel.state.processingProgress * 100))%")
                    .font(.system(size: FolioFontSize.bodySmall, weight: .semibold))
                    .foregroundStyle(viewModel.state.isProcessingComplete ? Color.folioSuccessStrong : Color.folioInk)

                Spacer()

                if !viewModel.state.isProcessingComplete {
                    Text(viewModel.state.processingStageLabel)
                        .font(.system(size: FolioFontSize.bodySmall, weight: .medium))
                        .foregroundStyle(Color.folioGold)
                        .lineLimit(1)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous)
                        .fill(Color.folioLine.opacity(0.4))
                        .frame(height: FolioSize.progressBarHeight)

                    RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous)
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * progressBarWidth, height: FolioSize.progressBarHeight)
                        .animation(.easeInOut(duration: FolioDuration.normal), value: viewModel.state.processingProgress)
                }
            }
            .frame(height: FolioSize.progressBarHeight)
        }
    }

    private var progressBarColor: Color {
        if viewModel.state.isProcessingComplete {
            return Color.folioSuccessStrong
        }
        return Color.folioGold
    }

    private var progressBarWidth: CGFloat {
        if viewModel.state.isProcessingComplete { return 1 }
        return CGFloat(viewModel.state.processingProgress)
    }

    private var failureBanner: some View {
        HStack(spacing: FolioSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.folioDanger)

            Text(viewModel.state.errorMessage ?? String(localized: "Processing Failed"))
                .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                .foregroundStyle(Color.folioDanger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FolioSpacing.md)
        .background(Color.folioDanger.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous)
                .stroke(Color.folioDanger.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
    }

    // MARK: - Actions

    private var failureActions: some View {
        VStack(spacing: FolioSpacing.md) {
            FolioSecondaryButton(
                title: String(localized: "Retry"),
                iconName: "arrow.clockwise",
                action: { viewModel.send(.retry) }
            )
            .disabled(viewModel.state.isRetrying)

            Button {
                viewModel.send(.deleteTapped)
            } label: {
                HStack(spacing: FolioSpacing.md) {
                    if viewModel.state.isDeleting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.folioDanger)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                    }
                    Text(String(localized: "Delete source"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FolioSpacing.xl)
                .foregroundStyle(Color.folioDanger)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                        .stroke(Color.folioDanger, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.state.isDeleting)
        }
    }

    private var completionActions: some View {
        VStack(spacing: FolioSpacing.md) {
            FolioPrimaryButton(
                title: String(localized: "Open source"),
                action: {
                    onStatusChanged(viewModel.state.source)
                    onSourceOpened?(viewModel.state.source)
                    onDismiss()
                }
            )

            FolioSecondaryButton(
                title: String(localized: "Ask"),
                iconName: "sparkles",
                action: {
                    onStatusChanged(viewModel.state.source)
                    onAskSource?(viewModel.state.source)
                    onDismiss()
                }
            )
        }
    }
}

#Preview {
    SourceProcessingSheet(
        source: Source(
            id: "processing-preview",
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
            processingState: .extractingText,
            processingError: "",
            createdAt: .now,
            updatedAt: .now
        ),
        uploadSourceUseCase: PreviewUploadSourceUseCase(),
        onDismiss: {},
        onDeleted: { _ in },
        onStatusChanged: { _ in }
    )
}

private struct PreviewUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func deleteSource(id: String) async throws {}
    func retrySource(id: String) async throws -> Source { throw CancellationError() }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}
