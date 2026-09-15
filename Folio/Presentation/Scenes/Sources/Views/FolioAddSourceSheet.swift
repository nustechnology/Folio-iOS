import SwiftUI
import UniformTypeIdentifiers

struct FolioAddSourceSheet: View {
    @ObservedObject var viewModel: FolioAddSourceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFileImporterPresented = false

    var onSourceOpened: ((Source) -> Void)?
    var onAskSource: ((Source) -> Void)?
    var onProcessingComplete: ((Source) -> Void)?

    init(viewModel: FolioAddSourceViewModel, onSourceOpened: ((Source) -> Void)? = nil, onAskSource: ((Source) -> Void)? = nil, onProcessingComplete: ((Source) -> Void)? = nil) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onSourceOpened = onSourceOpened
        self.onAskSource = onAskSource
        self.onProcessingComplete = onProcessingComplete
        if let onProcessingComplete {
            viewModel.onProcessingComplete = onProcessingComplete
        }
    }

    private func heightForTab(_ tab: FolioAddSourceViewModel.AddSourceTab) -> PresentationDetent {
        let staticHeight: CGFloat = 230
        let contentHeight: CGFloat = switch tab {
        case .files: 190
        case .web:   305
        case .text:  463
        }
        return .height(staticHeight + contentHeight)
    }

    private var currentDetent: PresentationDetent {
        viewModel.state.isProcessing ? processingDetent : heightForTab(viewModel.state.selectedTab)
    }

    private var processingDetent: PresentationDetent {
        .height(ProcessingLayout.sheetHeight)
    }

    private enum ProcessingLayout {
        static let sheetHeight: CGFloat = 390
        static let buttonHeight: CGFloat = 60
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
            [currentDetent],
            selection: Binding(get: { currentDetent }, set: { _ in })
        )
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(24)
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
            tabSelector
            tabContent
            addSourceButton
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Add source"))
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(localized: "Bring files, links and text into this space for grounded answers."))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.top, headerTopPadding)
        .padding(.bottom, FolioSpacing.xl)
    }

    private var headerTopPadding: CGFloat {
        viewModel.state.selectedTab == .text ? FolioSpacing.xl4 : FolioSpacing.xl
    }

    private var tabSelector: some View {
        HStack(spacing: FolioSpacing.sm) {
            ForEach(FolioAddSourceViewModel.AddSourceTab.allCases) { tab in
                let isSelected = viewModel.state.selectedTab == tab
                Button {
                    viewModel.handle(.selectTab(tab))
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.white : Color.folioInkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? Color.folioOliveDark : Color.folioHomeSheetBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                                .stroke(isSelected ? Color.clear : Color.folioBorderLight, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.vertical, 6)
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
        fileUploadArea
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.vertical, FolioSpacing.md)
    }

    private var selectedFileInfo: String {
        let size = viewModel.state.selectedFileSize.fileSizeString
        guard let pageCount = viewModel.state.selectedFilePageCount, pageCount > 0 else { return size }
        let pageLabel = pageCount == 1 ? String(localized: "page") : String(localized: "pages")
        return "\(size) • \(pageCount) \(pageLabel)"
    }

    private var fileUploadArea: some View {
        VStack(spacing: FolioSpacing.lg) {
            Button {
                isFileImporterPresented = true
            } label: {
                VStack(spacing: FolioSpacing.md) {
                    if viewModel.state.selectedFileURL != nil, !viewModel.state.selectedFileName.isEmpty {
                        Image(systemName: "doc.text")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(Color.folioHomeUploadIcon)

                        Text(String(localized: "Selected: \(viewModel.state.selectedFileName)"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.folioInk)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Text(selectedFileInfo)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)

                        Text(String(localized: "Tap to choose a different file"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(Color.folioHomeUploadIcon)

                        Text(String(localized: "Tap to upload a file"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.folioInkMuted)

                        VStack(spacing: FolioSpacing.xs) {
                            Text(String(localized: "PDF, DOCX, EPUB, MD, TXT, PPTX, XLSX, CSV"))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.folioInkSoft)
                                .multilineTextAlignment(.center)

                            Text(String(localized: "Max 50 MB per file"))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.folioInkSoft)
                        }
                        .padding(.top, FolioSpacing.md)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(Color.folioHomeSheetBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(Color.folioFieldBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
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

            if let error = viewModel.state.fileError {
                Text(error)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioDanger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var webTab: some View {
        VStack(alignment: .leading, spacing: FolioSpacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Article URL"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.folioHomeTypeTextText)

                PlaceholderUITextField(
                    placeholder: String(localized: "https://example.org/care-technology-adoption"),
                    placeholderColor: UIColor(Color.folioInkSoft),
                    font: .systemFont(ofSize: 14, weight: .regular),
                    textColor: UIColor(Color.folioInk),
                    keyboardType: .URL,
                    isSecureTextEntry: false,
                    autocorrectionType: .no,
                    autocapitalizationType: .none,
                    text: Binding(
                        get: { viewModel.state.webURL },
                        set: { viewModel.handle(.webURLChanged($0)) }
                    )
                )
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(viewModel.state.webURLError != nil ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))

                if let error = viewModel.state.webURLError {
                    Text(error)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioDanger)
                        .padding(.leading, 4)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Title"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.folioHomeTypeTextText)

                PlaceholderUITextField(
                    placeholder: String(localized: "Care Technology Adoption Survey 2026"),
                    placeholderColor: UIColor(Color.folioInkSoft),
                    font: .systemFont(ofSize: 14, weight: .regular),
                    textColor: UIColor(Color.folioInk),
                    keyboardType: .default,
                    isSecureTextEntry: false,
                    autocorrectionType: .default,
                    autocapitalizationType: .sentences,
                    text: Binding(
                        get: { viewModel.state.webTitle },
                        set: { viewModel.handle(.webTitleChanged($0)) }
                    )
                )
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.webTitle.count)/255")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Author"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.folioHomeTypeTextText)

                PlaceholderUITextField(
                    placeholder: String(localized: "Care Systems Association"),
                    placeholderColor: UIColor(Color.folioInkSoft),
                    font: .systemFont(ofSize: 14, weight: .regular),
                    textColor: UIColor(Color.folioInk),
                    keyboardType: .default,
                    isSecureTextEntry: false,
                    autocorrectionType: .default,
                    autocapitalizationType: .words,
                    text: Binding(
                        get: { viewModel.state.webAuthor },
                        set: { viewModel.handle(.webAuthorChanged($0)) }
                    )
                )
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.webAuthor.count)/100")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.vertical, FolioSpacing.md)
    }

    private var manualTab: some View {
        VStack(alignment: .leading, spacing: FolioSpacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Title"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.folioHomeTypeTextText)

                PlaceholderUITextField(
                    placeholder: String(localized: "Provider workshop evidence"),
                    placeholderColor: UIColor(Color.folioInkSoft),
                    font: .systemFont(ofSize: 14, weight: .regular),
                    textColor: UIColor(Color.folioInk),
                    keyboardType: .default,
                    isSecureTextEntry: false,
                    autocorrectionType: .default,
                    autocapitalizationType: .sentences,
                    text: Binding(
                        get: { viewModel.state.manualTitle },
                        set: { viewModel.handle(.manualTitleChanged($0)) }
                    )
                )
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.manualTitle.count)/255")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Author"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.folioHomeTypeTextText)

                PlaceholderUITextField(
                    placeholder: String(localized: "Internal Research"),
                    placeholderColor: UIColor(Color.folioInkSoft),
                    font: .systemFont(ofSize: 14, weight: .regular),
                    textColor: UIColor(Color.folioInk),
                    keyboardType: .default,
                    isSecureTextEntry: false,
                    autocorrectionType: .default,
                    autocapitalizationType: .words,
                    text: Binding(
                        get: { viewModel.state.manualAuthor },
                        set: { viewModel.handle(.manualAuthorChanged($0)) }
                    )
                )
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.manualAuthor.count)/100")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Content"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.folioHomeTypeTextText)

                ZStack(alignment: .topLeading) {
                    if viewModel.state.manualContent.isEmpty {
                        Text(String(localized: "Frontline coordinators described repeated entry across scheduling, incident, and compliance systems."))
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
                    .foregroundStyle(Color.folioInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(12)
                }
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(viewModel.state.manualContentError != nil ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))

                HStack {
                    Spacer()
                    Text("\(viewModel.state.manualContent.count)/100,000")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }

                if let error = viewModel.state.manualContentError {
                    Text(error)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioDanger)
                        .padding(.leading, 4)
                }
            }
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.vertical, FolioSpacing.md)
    }

    private var addSourceButton: some View {
        VStack(spacing: 0) {
            if let error = viewModel.state.submitError {
                Text(error)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.folioDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FolioSpacing.xl3)
                    .padding(.top, FolioSpacing.lg)
            }

            HStack(spacing: FolioSpacing.lg) {
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Cancel"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FolioSpacing.xl2)
                        .foregroundStyle(Color.folioInk)
                        .background(Color.folioHomeSheetBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous)
                                .stroke(Color.folioBorderLight, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.state.isSubmitting)

                FolioPrimaryButton(
                    title: String(localized: "Add source"),
                    isEnabled: viewModel.isSubmitEnabled,
                    verticalPadding: FolioSpacing.xl2,
                    action: { viewModel.handle(.addSource) }
                )
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.top, FolioSpacing.md)
            .padding(.bottom, 6)
        }
    }

    private var processingView: some View {
        VStack(spacing: 0) {
            processingHeader

            ScrollView {
                VStack(spacing: FolioSpacing.xl3) {
                    processingStatusCard

                    if viewModel.state.isProcessingFailed {
                        failureBanner
                        failureActions
                    } else if !viewModel.state.isProcessing && !viewModel.state.isProcessingComplete {
                        Button {
                            viewModel.handle(.resetToAddForm)
                        } label: {
                            Text(String(localized: "Add another source"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.folioOliveDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.folioSurfaceStrong)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous)
                                        .stroke(Color.folioBorderLight, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl4)
            }
        }
    }

    private var processingStatusCard: some View {
        VStack(spacing: FolioSpacing.xl5) {
            stageList

            if !viewModel.state.isProcessingFailed {
                progressSection
            }

            if viewModel.state.isProcessingComplete {
                completionActions
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FolioSpacing.xl2)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                .stroke(Color.folioLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
    }

    private var processingHeader: some View {
        VStack(alignment: .leading, spacing: FolioSpacing.sm) {
            Text(String(localized: "Processing"))
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)

            Text(processingSubtitle)
                .font(.system(size: FolioFontSize.body, weight: .regular))
                .foregroundStyle(Color.folioInkMuted)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.top, FolioSpacing.xl3)
        .padding(.bottom, FolioSpacing.xl3)
    }

    private var processingSubtitle: String {
        if let source = viewModel.state.processingSource,
           source.sourceType == .file, !source.fileName.isEmpty {
            return source.fileName
        }
        let title = viewModel.state.processingSourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? String(localized: "Untitled Source") : title
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: FolioSpacing.md) {
            Text("\(Int(displayProgress * 100))%")
                .font(.system(size: FolioFontSize.bodySmall, weight: .semibold))
                .foregroundStyle(Color.folioInk)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous)
                        .fill(Color.folioLine.opacity(0.4))
                        .frame(height: FolioSize.progressBarHeight)

                    RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous)
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * displayProgress, height: FolioSize.progressBarHeight)
                        .animation(.easeInOut(duration: FolioDuration.normal), value: displayProgress)
                }
            }
            .frame(height: FolioSize.progressBarHeight)
        }
    }

    private var displayProgress: Double {
        viewModel.state.isProcessingComplete ? 1 : viewModel.state.processingProgress
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
        VStack(spacing: 0) {
            ForEach(Array(viewModel.state.processingStages.enumerated()), id: \.offset) { index, item in
                stageRow(item)
                if index < viewModel.state.processingStages.count - 1 {
                    stageConnector
                }
            }
        }
    }

    private func stageRow(_ item: (stage: FolioAddSourceViewModel.ProcessingStage, status: FolioAddSourceViewModel.StageStatus)) -> some View {
        HStack(spacing: FolioSpacing.md) {
            stageIcon(for: item.status)
                .frame(width: FolioSize.iconXl, height: FolioSize.iconXl)

            Text(item.stage.title)
                .font(.system(size: FolioFontSize.bodyLarge, weight: item.status == .active ? .semibold : .regular))
                .foregroundStyle(stageTextColor(for: item.status))

            Spacer()
        }
    }

    private var stageConnector: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.folioLine)
                .frame(width: 2, height: FolioSpacing.lg)
                .frame(width: FolioSize.iconXl)
            Spacer()
        }
    }

    private func stageIcon(for status: FolioAddSourceViewModel.StageStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Circle()
                    .stroke(Color.folioLine, lineWidth: 2)
                    .frame(width: 24, height: 24)
            case .active:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.folioGold)
                    .scaleEffect(1.0)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.folioSuccessStrong)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 24))
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
        VStack(spacing: FolioSpacing.sm) {
            HStack(spacing: FolioSpacing.sm) {
                FolioPrimaryButton(
                    title: String(localized: "Open source"),
                    action: {
                        if let source = viewModel.state.processingSource {
                            onSourceOpened?(source)
                        }
                        dismiss()
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: ProcessingLayout.buttonHeight)

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
                .frame(maxWidth: .infinity)
                .frame(height: ProcessingLayout.buttonHeight)
            }

            Button {
                viewModel.handle(.resetToAddForm)
            } label: {
                Text(String(localized: "Add another source"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.folioOliveDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.folioSurfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous)
                            .stroke(Color.folioBorderLight, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
