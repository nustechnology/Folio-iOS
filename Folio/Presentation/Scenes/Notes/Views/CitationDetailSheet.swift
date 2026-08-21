import SwiftUI

struct CitationDetailSheet: View {
    let citation: NoteCitation
    let onOpenSource: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var sourceTypeTitle: String {
        switch citation.sourceType {
        case SourceType.manual.rawValue: "NOTE"
        case SourceType.web.rawValue: "WEB"
        case SourceType.file.rawValue: "FILE"
        default: citation.sourceType.uppercased()
        }
    }

    private var locationDetails: [String] {
        [citation.locationLabel, citation.pageReference, citation.sectionReference]
            .compactMap { value in
                guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                    return nil
                }
                return value
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FolioSpacing.md) {
                Text("\(String(localized: "Citation")) · \(citation.sourceTitle)")
                    .font(.system(size: FolioFontSize.title3, weight: .semibold))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: FolioFontSize.body, weight: .medium))
                        .foregroundStyle(Color.folioInkMuted)
                        .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Close"))
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.vertical, FolioSpacing.xl)

            Divider().overlay(Color.folioBorderLight)

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.xl) {
                    HStack(alignment: .center, spacing: FolioSpacing.sm) {
                        FolioKindBadge(
                            title: sourceTypeTitle,
                            backgroundColor: Color.folioHomeTypeFileBackground,
                            textColor: Color.folioHomeTypeFileText
                        )
                        Spacer(minLength: 0)
                        if let author = citation.sourceAuthor?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty {
                            Text(author)
                                .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                                .foregroundStyle(Color.folioInkMuted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if let snippet = citation.snippet?.trimmingCharacters(in: .whitespacesAndNewlines), !snippet.isEmpty {
                        FolioCard(content: Text("“\(snippet)”")
                            .font(.system(size: FolioFontSize.bodyLarge, weight: .regular))
                            .foregroundStyle(Color.folioInk)
                            .frame(maxWidth: .infinity, alignment: .leading))
                    }

                    if !locationDetails.isEmpty {
                        Text(locationDetails.joined(separator: " · "))
                            .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                            .foregroundStyle(Color.folioInkMuted)
                    }
                }
                .padding(FolioSpacing.xl3)
            }

            Divider().overlay(Color.folioBorderLight)

            HStack(spacing: FolioSpacing.lg) {
                FolioSecondaryButton(title: String(localized: "Close")) {
                    dismiss()
                }
                FolioPrimaryButton(title: String(localized: "Open in source")) {
                    onOpenSource()
                }
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.top, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.md)
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.citationSheetMinH, maxHeight: FolioSize.citationSheetMaxH)
        .presentationDragIndicator(.visible)
    }
}
