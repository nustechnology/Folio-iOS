import SwiftUI
import UniformTypeIdentifiers

struct FolioAddSourceSheet: View {
    @StateObject private var viewModel: FolioAddSourceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFileImporterPresented = false
    @State private var sheetDetent: PresentationDetent = .height(464)

    var onSourceOpened: ((Source) -> Void)?
    var onAskSource: ((Source) -> Void)?

    init(uploadUseCase: any UploadSourceUseCaseProtocol, spaceId: String, onSourceOpened: ((Source) -> Void)? = nil, onAskSource: ((Source) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: FolioAddSourceViewModel(uploadUseCase: uploadUseCase, spaceId: spaceId))
        self.onSourceOpened = onSourceOpened
        self.onAskSource = onAskSource
    }

    private func heightForTab(_ tab: FolioAddSourceViewModel.AddSourceTab) -> PresentationDetent {
        let staticHeight: CGFloat = 224
        let contentHeight: CGFloat = switch tab {
        case .files: 240
        case .web:   320
        case .text:  460
        }
        return .height(staticHeight + contentHeight)
    }

    var body: some View {
        Group {
            if viewModel.state.isProcessing {
                processingView
            } else {
                formView
            }
        }
        .presentationDetents(
            viewModel.state.isProcessing ? [.large] : [heightForTab(viewModel.state.selectedTab)],
            selection: $sheetDetent
        )
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.state.isProcessing)
        .presentationBackground(Color.white)
        .onChange(of: viewModel.state.selectedTab) { _, tab in
            sheetDetent = heightForTab(tab)
        }
        .onChange(of: viewModel.state.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .deleteConfirmationOverlay(
            isPresented: viewModel.state.showDeleteConfirmation,
            title: String(localized: "Are you sure you want to delete this source?"),
            message: String(localized: "This permanently removes the source and its retrieval data."),
            onCancel: { viewModel.handle(.dismissDeleteConfirmation) },
            onDelete: { viewModel.handle(.deleteSourceConfirmed) }
        )
    }

    private var formView: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.folioLine)
            tabSelector
            Divider().background(Color.folioLine)
            tabContent
            addSourceButton
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Add Source"))
                .font(.custom("CormorantGaramond-Medium", size: 24))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(localized: "Bring PDFs, links and text into this space for grounded answers"))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.folioInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(FolioAddSourceViewModel.AddSourceTab.allCases) { tab in
                Button {
                    viewModel.handle(.selectTab(tab))
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: viewModel.state.selectedTab == tab ? .bold : .regular))
                        .foregroundStyle(viewModel.state.selectedTab == tab ? Color.white : Color.folioInkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.state.selectedTab == tab ? Color.folioOlive : Color.folioSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch viewModel.state.selectedTab {
            case .files:
                filesTab
            case .web:
                webTab
            case .text:
                manualTab
            }
        }
    }

    private var filesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let url = viewModel.state.selectedFileURL, !viewModel.state.selectedFileName.isEmpty {
                filePreviewCard(url: url)
            } else {
                fileUploadArea
            }
        }
        .padding(20)
    }

    private var fileUploadArea: some View {
        VStack(spacing: 12) {
            Button {
                isFileImporterPresented = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.folioGold)

                    Text(String(localized: "Tap to select a file"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.folioInkMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.folioLine, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: FolioAddSourceViewModel.supportedExtensions.compactMap { UTType(filenameExtension: $0) },
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    viewModel.handle(.fileSelected(urls.first))
                case .failure:
                    break
                }
            }

            VStack(spacing: 4) {
                Text(String(localized: "Accepted formats: .pdf, .docx, .txt, .md, .pptx, .xlsx, .csv, .epub"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
                    .multilineTextAlignment(.center)

                Text(String(localized: "Max 50 MB"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
            }

            if let error = viewModel.state.fileError {
                Text(error)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioDanger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func filePreviewCard(url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: fileIconForExtension(url.pathExtension))
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.folioOlive)
                .frame(width: 48, height: 48)
                .background(Color.folioGold.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.state.selectedFileName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(2)

                Text(viewModel.state.selectedFileSize.fileSizeString)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
            }

            Spacer()

            Button {
                viewModel.handle(.removeFile)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInkMuted)
                    .frame(width: 28, height: 28)
                    .background(Color.folioSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Remove file"))
        }
        .padding(14)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.folioLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fileIconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.richtext"
        case "docx", "txt", "md": return "doc.text"
        case "pptx": return "chart.bar.doc.horizontal"
        case "xlsx", "csv": return "tablecells"
        case "epub": return "book"
        default: return "doc"
        }
    }

    private var webTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Article URL"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInk)

                TextField(String(localized: "https://example.com/article"), text: Binding(
                    get: { viewModel.state.webURL },
                    set: { viewModel.handle(.webURLChanged($0)) }
                ))
                .font(.system(size: 14, weight: .regular))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(viewModel.state.webURLError != nil ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let error = viewModel.state.webURLError {
                    Text(error)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioDanger)
                        .padding(.leading, 4)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Title"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInk)

                TextField(String(localized: "Enter article title (optional)"), text: Binding(
                    get: { viewModel.state.webTitle },
                    set: { viewModel.handle(.webTitleChanged($0)) }
                ))
                .font(.system(size: 14, weight: .regular))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.webTitle.count)/255")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Author"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInk)

                TextField(String(localized: "Enter author name (optional)"), text: Binding(
                    get: { viewModel.state.webAuthor },
                    set: { viewModel.handle(.webAuthorChanged($0)) }
                ))
                .font(.system(size: 14, weight: .regular))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.webAuthor.count)/100")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }
        }
        .padding(20)
    }

    private var manualTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Title"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInk)

                TextField(String(localized: "Enter title (optional)"), text: Binding(
                    get: { viewModel.state.manualTitle },
                    set: { viewModel.handle(.manualTitleChanged($0)) }
                ))
                .font(.system(size: 14, weight: .regular))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.manualTitle.count)/255")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Author"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInk)

                TextField(String(localized: "Enter author name (optional)"), text: Binding(
                    get: { viewModel.state.manualAuthor },
                    set: { viewModel.handle(.manualAuthorChanged($0)) }
                ))
                .font(.system(size: 14, weight: .regular))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.manualAuthor.count)/100")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Content"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioInk)

                ZStack(alignment: .bottomTrailing) {
                    ZStack(alignment: .topLeading) {
                        if viewModel.state.manualContent.isEmpty {
                            Text(String(localized: "Paste or type your text content here..."))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.folioInkSoft)
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                        }

                        TextEditor(text: Binding(
                            get: { viewModel.state.manualContent },
                            set: { viewModel.handle(.manualContentChanged($0)) }
                        ))
                        .font(.system(size: 14, weight: .regular))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(12)
                    }
                    .background(Color.folioSurfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(viewModel.state.manualContentError != nil ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("\(viewModel.state.manualContent.count)/100,000")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                if let error = viewModel.state.manualContentError {
                    Text(error)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioDanger)
                        .padding(.leading, 4)
                }
            }
        }
        .padding(20)
    }

    private var addSourceButton: some View {
        VStack(spacing: 0) {
            Divider().background(Color.folioLine)

            if let error = viewModel.state.submitError {
                Text(error)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Cancel"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.folioInk)
                        .background(Color.folioSurfaceStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.folioFieldBorder, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.state.isSubmitting)

                FolioPrimaryButton(
                    title: String(localized: "Add source"),
                    action: { viewModel.handle(.addSource) }
                )
                .disabled(viewModel.state.isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
    }

    private var processingView: some View {
        VStack(spacing: 0) {
            processingHeader
            Divider().background(Color.folioLine)

            ScrollView {
                VStack(spacing: 20) {
                    sourceTitleSection

                    processingStatusCard

                    if viewModel.state.isProcessingFailed {
                        failureBanner
                        failureActions
                    }
                }
                .padding(20)
            }
        }
    }

    private var processingStatusCard: some View {
        VStack(spacing: 24) {
            stageList

            if !viewModel.state.isProcessingFailed {
                progressSection
            }

            if viewModel.state.isProcessingComplete {
                completionActions
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.folioLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var processingHeader: some View {
        HStack {
            Button {
                viewModel.handle(.dismissProcessing)
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(String(localized: "Back to sources"))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.folioInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Back to sources"))

            Spacer()

            Button {
                viewModel.handle(.dismissProcessing)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.folioInkMuted)
                    .frame(width: 36, height: 36)
                    .background(Color.folioSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .overlay(alignment: .center) {
            Text(String(localized: "Processing"))
                .font(.custom("CormorantGaramond-Medium", size: 20))
                .foregroundStyle(Color.folioInk)
        }
    }

    private var sourceTitleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.state.processingSourceTitle)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(Color.folioInk)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.state.isProcessingFailed ? String(localized: "Failed") : "\(Int(viewModel.state.processingProgress * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(viewModel.state.isProcessingFailed ? Color.folioDanger : Color.folioInk)

                Spacer()

                if !viewModel.state.isProcessingFailed {
                    Text(viewModel.state.isProcessingComplete ? String(localized: "Ready") : viewModel.state.processingStageLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(viewModel.state.isProcessingComplete ? Color.folioSuccessStrong : Color.folioGold)
                        .lineLimit(1)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.folioLine.opacity(0.4))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * CGFloat(viewModel.state.isProcessingFailed ? 0 : viewModel.state.processingProgress), height: 8)
                        .animation(.easeInOut(duration: FolioDuration.normal), value: viewModel.state.processingProgress)
                }
            }
            .frame(height: 8)
        }
    }

    private var progressBarColor: Color {
        if viewModel.state.isProcessingFailed {
            return Color.folioDanger
        }
        if viewModel.state.isProcessingComplete {
            return Color.folioSuccessStrong
        }
        return Color.folioGold
    }

    private var stageList: some View {
        VStack(spacing: 12) {
            ForEach(Array(viewModel.state.processingStages.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 12) {
                    stageIcon(for: item.status)
                        .frame(width: 24, height: 24)

                    Text(item.stage.title)
                        .font(.system(size: 13, weight: item.status == .active ? .semibold : .regular))
                        .foregroundStyle(stageTextColor(for: item.status))

                    Spacer()
                }
            }
        }
    }

    private func stageIcon(for status: FolioAddSourceViewModel.StageStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Circle()
                    .stroke(Color.folioLine, lineWidth: 2)
                    .frame(width: 20, height: 20)
            case .active:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.folioGold)
                    .scaleEffect(0.8)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.folioSuccessStrong)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.folioDanger)
            }
        }
    }

    private func stageTextColor(for status: FolioAddSourceViewModel.StageStatus) -> Color {
        switch status {
        case .pending: return Color.folioInkSoft
        case .active: return Color.folioInk
        case .completed: return Color.folioInk
        case .failed: return Color.folioDanger
        }
    }

    private var failureBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.folioDanger)

            Text(String(localized: "Processing failed: Could not extract information from the document."))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.folioDanger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.folioDanger.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.folioDanger.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var failureActions: some View {
        VStack(spacing: 12) {
            if let deletionError = viewModel.state.deletionError {
                Text(deletionError)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }

            FolioSecondaryButton(
                title: String(localized: "Retry"),
                iconName: "arrow.clockwise",
                action: { viewModel.handle(.retryProcessing) }
            )

            Button {
                viewModel.handle(.deleteSourceTapped)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(localized: "Delete source"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.folioDanger)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioDanger, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var completionActions: some View {
        VStack(spacing: 12) {
            FolioPrimaryButton(
                title: String(localized: "Open source"),
                action: {
                    if let source = viewModel.state.processingSource {
                        onSourceOpened?(source)
                    }
                    dismiss()
                }
            )

            FolioSecondaryButton(
                title: String(localized: "Ask"),
                iconName: "sparkle",
                action: {
                    if let source = viewModel.state.processingSource {
                        onAskSource?(source)
                    }
                    dismiss()
                }
            )
        }
    }
}
