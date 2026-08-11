import SwiftUI

struct NoteDetailView: View {
    let note: Note
    let onEdit: () -> Void
    let onConvert: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.lg)
            
            HStack(alignment: .top, spacing: FolioSpacing.md) {
                Text(note.title)
                    .font(.system(size: FolioFontSize.heading, weight: .regular, design: .serif))
                    .foregroundStyle(Color.folioInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: FolioFontSize.body, weight: .medium))
                        .foregroundStyle(Color.folioInk)
                        .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                        .background(Color.folioHomeSheetBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                                .stroke(Color.folioHomeSheetHandle.opacity(0.8), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Close"))
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.xl3)
            
            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.md) {
                    metadata
                    
                    FolioCard(
                        content: Text(note.content)
                            .font(.system(size: FolioFontSize.bodyLarge, weight: .regular))
                            .foregroundStyle(Color.folioInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading),
                        height: 160
                    )
                    
                    actionButtons
                }
                .padding(.horizontal, FolioSpacing.xl3)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.noteDetailSheetMinH, maxHeight: FolioSize.noteDetailSheetMaxH)
        .presentationDragIndicator(.hidden)
    }
    
    private var metadata: some View {
        HStack(spacing: FolioSpacing.sm) {
            FolioKindBadge(
                title: note.originType.title,
                backgroundColor: Color.folioHomeTypeFileBackground,
                textColor: Color.folioHomeTypeFileText
            )
            
            if let citationCount = note.citationCount, note.hasCitations {
                FolioKindBadge(
                    title: citationCount.noteCitationDisplayLabel,
                    backgroundColor: Color.folioHomeTypeFileBackground,
                    textColor: Color.folioHomeTypeFileText
                )
            }
            
            Spacer(minLength: 0)
            
            detailDateRow(
                date: note.updatedAt
            )
        }
    }
    
    private func detailDateRow(date: Date) -> some View {
        HStack(spacing: FolioSpacing.xs) {
            Text(date.noteListDisplayLabel)
                .font(.system(size: FolioFontSize.caption2, weight: .regular))
                .foregroundStyle(Color.folioInkMuted)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: FolioSpacing.lg) {
            FolioSecondaryButton(
                title: String(localized: "Convert to Source"),
                action: onConvert
            )

            FolioPrimaryButton(
                title: String(localized: "Edit"),
                action: onEdit
            )
        }
        .padding(.top, FolioSpacing.sm)
    }
}
