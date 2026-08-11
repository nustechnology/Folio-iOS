import SwiftUI

struct NoteRow: View {
    let note: NoteSummary
    let onOpen: () -> Void
    let onActions: () -> Void
    
    var body: some View {
        FolioCard(
            content: HStack(alignment: .top, spacing: FolioSpacing.sm) {
                Button(action: onOpen) {
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
                            
                            Spacer(minLength: FolioSpacing.xs)
                            
                            HStack(alignment: .center, spacing: FolioSpacing.sm) {
                                HStack(spacing: 6) {
                                     FolioKindBadge(
                                         title: note.originType.title,
                                         backgroundColor: .folioHomeTypeFileBackground,
                                         textColor: .folioHomeTypeFileText
                                     )
                                    
                                    FolioKindBadge(
                                        title: (note.citationCount ?? 0).noteCitationDisplayLabel,
                                        backgroundColor: .folioHomeTypeFileBackground,
                                        textColor: .folioHomeTypeFileText
                                    )
                                }
                                
                                Spacer(minLength: FolioSpacing.xs)
                                
                                Text(note.updatedAt.noteListDisplayLabel)
                                    .font(.system(size: FolioFontSize.caption2, weight: .regular))
                                    .foregroundStyle(Color.folioInkSoft)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                
                Button(action: onActions) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: FolioFontSize.body, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                        .rotationEffect(.degrees(90))
                        .padding(.top, FolioSpacing.sm)
                }
                .buttonStyle(.plain)
                .frame(width: FolioSize.iconSm, height: FolioSize.iconSm)
                .accessibilityLabel(
                    String.localizedStringWithFormat(
                        String(localized: "More options for %@"),
                        note.title
                    )
                )
            }
        )
    }
}
