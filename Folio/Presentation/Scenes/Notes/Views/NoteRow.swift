import SwiftUI

struct NoteRow: View {
    let note: NoteSummary
    let onOpen: () -> Void
    let onActions: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                FolioCard(content: cardContent)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onActions) {
                Image(systemName: "ellipsis")
                    .font(.system(size: FolioFontSize.body, weight: .semibold))
                    .foregroundStyle(Color.folioInk)
                    .rotationEffect(.degrees(90))
                    .frame(width: FolioSize.tapTarget, height: FolioSize.tapTarget)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .zIndex(1)
            .accessibilityLabel(
                String.localizedStringWithFormat(
                    String(localized: "More options for %@"),
                    note.title
                )
            )
        }
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: FolioSpacing.lg) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                .foregroundStyle(Color.folioHomeTypeFileText)
                .frame(width: FolioSize.chipHeight, height: FolioSize.chipHeight)
                .background(Color.folioHomeTypeFileBackground)
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(note.title)
                    .font(.system(size: FolioFontSize.subheadline, design: .serif))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(note.contentPreview)
                    .font(.system(size: FolioFontSize.small))
                    .foregroundStyle(Color.folioInkSoft)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.trailing, FolioSpacing.sm)

                Spacer(minLength: FolioSpacing.xs)

                HStack(alignment: .center, spacing: FolioSpacing.sm) {
                    HStack(spacing: 6) {
                        FolioKindBadge(
                            title: note.originType.title,
                            backgroundColor: note.originType.badgeBackgroundColor,
                            textColor: note.originType.badgeTextColor,
                            style: .roundedRectangle(cornerRadius: FolioRadius.sm),
                            horizontalPadding: FolioSpacing.lg,
                            verticalPadding: FolioSpacing.sm
                        )

                        FolioKindBadge(
                            title: (note.citationCount ?? 0).noteCitationDisplayLabel,
                            backgroundColor: note.originType.badgeBackgroundColor,
                            textColor: note.originType.badgeTextColor,
                            style: .roundedRectangle(cornerRadius: FolioRadius.sm),
                            horizontalPadding: FolioSpacing.lg,
                            verticalPadding: FolioSpacing.sm
                        )
                    }

                    Spacer(minLength: FolioSpacing.xs)

                    Text(note.updatedAt.noteListDisplayLabel)
                        .font(.system(size: FolioFontSize.caption2, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.trailing, FolioSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
