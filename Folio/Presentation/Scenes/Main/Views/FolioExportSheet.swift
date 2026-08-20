import SwiftUI

struct FolioExportSheet: View {
    let onCopy: () -> Void
    let onExportMarkdown: () -> Void
    let onPrint: () -> Void
    let onDismiss: () -> Void

    private enum Mode {
        case actions
        case export
    }

    private enum ExportOption {
        case markdown
        case printPDF
    }

    @State private var mode: Mode = .actions
    @State private var selectedOption: ExportOption = .markdown

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.folioHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, 12)

            if mode == .actions {
                actionsContent
            } else {
                exportContent
            }
        }
        .presentationBackground(Color.folioSurfaceStrong)
        .presentationDetents(mode == .actions ? [.height(250)] : [.height(350)])
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var actionsContent: some View {
        VStack(spacing: 0) {
            Text(String(localized: "Notebook actions"))
                .font(.custom("CormorantGaramond-Medium", size: 24))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl3)

            VStack(spacing: FolioSpacing.lg) {
                SheetActionButton(title: String(localized: "Copy notebook"), action: onCopy)

                SheetActionButton(title: String(localized: "Export"), action: {
                    withAnimation { mode = .export }
                })
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.xl4)
        }
    }

    private var exportContent: some View {
        VStack(spacing: 0) {
            Text(String(localized: "Export notebook"))
                .font(.custom("CormorantGaramond-Medium", size: 24))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl3)

            VStack(spacing: FolioSpacing.lg) {
                SelectableExportOption(
                    title: String(localized: "Markdown"),
                    subtitle: String(localized: ".md file"),
                    isSelected: selectedOption == .markdown,
                    action: { selectedOption = .markdown }
                )

                SelectableExportOption(
                    title: String(localized: "Print / PDF"),
                    subtitle: String(localized: "System print"),
                    isSelected: selectedOption == .printPDF,
                    action: { selectedOption = .printPDF }
                )
            }
            .padding(.horizontal, FolioSpacing.xl3)

            HStack(spacing: FolioSpacing.lg) {
                Button(action: onDismiss) {
                    Text(String(localized: "Cancel"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(Color.folioInk)
                        .background(Color.folioSurfaceStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous)
                                .stroke(Color.folioFieldBorder, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)

                FolioPrimaryButton(title: String(localized: "Export"), action: {
                    switch selectedOption {
                    case .markdown: onExportMarkdown()
                    case .printPDF: onPrint()
                    }
                })
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.top, FolioSpacing.xl)
            .padding(.bottom, FolioSpacing.xl4)
        }
    }
}

private struct SheetActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SelectableExportOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isSelected ? Color.folioGold : Color.folioInkSoft, lineWidth: 1.5)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.folioGold)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.folioGoldSoft.opacity(0.5) : Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous)
                    .stroke(isSelected ? Color.folioGold : Color.folioFieldBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FolioExportSheet(
        onCopy: {},
        onExportMarkdown: {},
        onPrint: {},
        onDismiss: {}
    )
}
