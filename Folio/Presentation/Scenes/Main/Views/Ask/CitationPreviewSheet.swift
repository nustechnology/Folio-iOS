import SwiftUI

// MARK: - Citation preview sheet (mirrors CitationPreviewBottomSheet.kt)

struct CitationPreviewSheet: View {
    let citation: AskCitation
    let onOpenInSource: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var headerHeight: CGFloat = 0
    @State private var sheetHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.xl3) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(citation.sourceTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.folioInk)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        FolioKindBadge(
                            title: citation.badgeLabel,
                            backgroundColor: Color.folioHomeTypeWebBackground,
                            textColor: Color.folioHomeTypeWebText,
                            style: .roundedRectangle(cornerRadius: FolioRadius.sm),
                            horizontalPadding: FolioSpacing.lg,
                            verticalPadding: FolioSpacing.md
                        )
                    }

                    Text("Evidence")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.folioInkMuted)

                    VStack(alignment: .leading, spacing: FolioSpacing.lg) {
                        if !citation.locationLabel.isEmpty {
                            Text(citation.locationLabel)
                                .font(.system(size: FolioFontSize.small, weight: .medium))
                                .foregroundStyle(Color.folioInkMuted)
                                .textCase(.uppercase)
                                .lineSpacing(4)
                        }

                        Text(citation.evidenceText.isEmpty ? String(localized: "No evidence text available.") : citation.evidenceText)
                            .font(.system(size: FolioFontSize.bodyLarge, weight: .regular))
                            .foregroundStyle(Color.folioInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(FolioSpacing.lg)
                            .background(Color.folioGoldSoft.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
                    }
                    .padding(FolioSpacing.xl)
                    .background(Color.folioSurfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.xl, style: .continuous)
                            .stroke(Color.folioLine, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xl, style: .continuous))

                    HStack(spacing: 12) {
                        FolioSecondaryButton(title: String(localized: "Close")) {
                            dismiss()
                        }

                        FolioPrimaryButton(
                            title: String(localized: "Open in source"),
                            isEnabled: citation.canOpenInSource
                        ) {
                            onOpenInSource()
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl3)
                .measureHeight($sheetHeight)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .presentationDetents(
            sheetHeight > 0 && headerHeight > 0
            ? [.height(min(sheetHeight + headerHeight, FolioSize.citationSheetMaxH))]
            : [.medium]
        )
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: FolioSpacing.sm) {
            Text("Citation")
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)
            Text("[\(citation.index)]")
                .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                .foregroundStyle(Color.folioInkMuted)
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.top, FolioSpacing.xl3)
        .padding(.bottom, FolioSpacing.xl3)
        .measureHeight($headerHeight)
    }
}
