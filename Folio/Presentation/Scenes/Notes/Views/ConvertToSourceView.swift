import SwiftUI

struct ConvertToSourceView: View {
    let note: Note
    let isCreating: Bool
    let onCreate: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var headerHeight: CGFloat = 0
    @State private var sheetHeight: CGFloat = 0
    
    init(note: Note, isCreating: Bool = false, onCreate: @escaping (String) -> Void) {
        self.note = note
        self.isCreating = isCreating
        self.onCreate = onCreate
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.xl2) {
                    snapshotNotice
                    
                    sourceTitle
                    
                    VStack(alignment: .leading, spacing: FolioSpacing.sm) {
                        Text(String(localized: "Snapshot"))
                            .font(.system(size: FolioFontSize.body, weight: .medium))
                            .foregroundStyle(Color.folioHomeTypeTextText)
                        
                        FolioCard(
                            content: CitationRichTextView(
                                content: note.content,
                                citationCount: note.citations.count
                            ),
                            height: .minimum(160),
                            backgroundColor: .folioHomeReadOnlyFieldBackground
                        )
                        actionButtons
                    }
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)
                .measureHeight($sheetHeight)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .dismissKeyboardOnTapOutside()
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .presentationDragIndicator(.hidden)
        .presentationDetents(
            sheetHeight > 0
            && headerHeight > 0
            ? [.height(sheetHeight + headerHeight), .large]
            : [.medium, .large]
        )
    }

    private var header: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.lg)

            Text(String(localized: "Convert to source"))
                .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.headingLarge))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl3)
        }
        .measureHeight($headerHeight)
    }

    private var sourceTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Source title"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.folioHomeTypeTextText)

            Text(note.title)
                .font(.system(size: 14))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 52)
                .background(Color.folioHomeReadOnlyFieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
    
    private var snapshotNotice: some View {
        HStack(spacing: 0) {
            Color.folioGold
                .frame(width: FolioSize.tabIndicatorH)
            
            Text("**A fixed snapshot will be created.** Later note edits will not change the source, and deleting the note leaves the source in place.")
            .font(.system(size: FolioFontSize.body, weight: .regular))
            .foregroundStyle(Color.folioInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FolioSpacing.lg)
            .padding(.vertical, FolioSpacing.lg)
        }
        .background(Color.folioHomeTypeBadgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
    }
    
    private var actionButtons: some View {
        HStack(spacing: FolioSpacing.lg) {
            FolioSecondaryButton(
                title: String(localized: "Cancel"),
                isDisabled: isCreating,
                action: { dismiss() }
            )
            
            FolioPrimaryButton(
                title: String(localized: "Create source"),
                isLoading: isCreating,
                isEnabled: !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: { onCreate(note.title.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        .padding(.top, FolioSpacing.sm)
        .padding(.bottom, FolioSpacing.xl)
        .background(Color.folioHomeSheetBackground)
    }
}
