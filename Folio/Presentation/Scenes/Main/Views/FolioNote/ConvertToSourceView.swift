import SwiftUI

struct ConvertToSourceView: View {
  let note: Note
  let onCreate: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var sourceTitle: String

  init(note: Note, onCreate: @escaping (String) -> Void) {
    self.note = note
    self.onCreate = onCreate
    _sourceTitle = State(initialValue: note.title)
  }

  var body: some View {
    VStack(spacing: 0) {
      RoundedRectangle(cornerRadius: FolioRadius.handle)
        .fill(Color.folioHomeSheetHandle)
        .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
        .padding(.top, FolioSpacing.sm)
        .padding(.bottom, FolioSpacing.lg)

      Text(String(localized: "Convert to source"))
        .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
        .foregroundStyle(Color.folioInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.bottom, FolioSpacing.xl3)

      ScrollView {
        VStack(alignment: .leading, spacing: FolioSpacing.xl2) {
          snapshotNotice

          FolioTextField(
            label: String(localized: "Source title"),
            text: $sourceTitle,
            style: .singleLine
          )

          VStack(alignment: .leading, spacing: FolioSpacing.sm) {
            Text(String(localized: "Snapshot"))
              .font(.system(size: FolioFontSize.bodySmall, weight: .medium))
              .foregroundStyle(Color.folioHomeTypeTextText)

            FolioCard(
              content: Text(note.content)
                .font(.system(size: FolioFontSize.body, weight: .regular))
                .foregroundStyle(Color.folioInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading),
              height: FolioSize.snapshotCardH
            )
            actionButtons
          }
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.bottom, FolioSpacing.xl)
      }
    }
    .background(Color.folioHomeSheetBackground)
    .presentationBackground(Color.folioHomeSheetBackground)
    .presentationCornerRadius(FolioRadius.xl2)
    .folioDynamicSheet(minHeight: FolioSize.conversionSheetMinH, maxHeight: FolioSize.conversionSheetMaxH)
    .presentationDragIndicator(.hidden)
  }

  private var snapshotNotice: some View {
    HStack(spacing: 0) {
      Color.folioGold
        .frame(width: FolioSize.tabIndicatorH)

      Text(
        String(
          localized:
            "A fixed snapshot will be created. Later note edits will not change the source.")
      )
      .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
      .foregroundStyle(Color.folioInk)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, FolioSpacing.lg)
      .padding(.vertical, FolioSpacing.lg)
    }
    .background(Color.folioGoldSoft.opacity(0.45))
    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
  }

  private var actionButtons: some View {
    HStack(spacing: FolioSpacing.lg) {
      FolioSecondaryButton(
        title: String(localized: "Cancel"),
        action: { dismiss() }
      )

      FolioPrimaryButton(
        title: String(localized: "Create source"),
        isDisabled: sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        action: { onCreate(sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)) }
      )
    }
    .padding(.top, FolioSpacing.sm)
    .padding(.bottom, FolioSpacing.xl)
    .background(Color.folioHomeSheetBackground)
  }
}
