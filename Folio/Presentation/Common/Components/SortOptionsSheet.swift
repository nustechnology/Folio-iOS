import SwiftUI

struct SortOptionsSheet<Option: SortOptionProtocol>: View {
  let title: String
  let options: [Option]
  let selectedValue: Option
  let onSelect: (Option) -> Void

  var body: some View {
    VStack(spacing: 0) {
      dragHandle
      Text(title)
        .font(.system(size: FolioFontSize.heading, design: .serif))
        .foregroundStyle(Color.folioInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FolioSpacing.xl2)
        .padding(.bottom, FolioSpacing.lg2)

      VStack(spacing: FolioSpacing.md) {
        ForEach(options, id: \.self) { option in
          let isSelected = option == selectedValue
          Button {
            onSelect(option)
          } label: {
            HStack(spacing: 8) {
              Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: FolioFontSize.title2, weight: .medium))
                .foregroundStyle(
                  isSelected ? Color.folioOlive : Color.folioFieldBorder
                )

              Text(option.displayTitle)
                .font(.system(size: FolioFontSize.body, weight: .medium))
                .foregroundStyle(Color.folioInk)

              Spacer()
            }
            .padding(.horizontal, FolioSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .background(isSelected ? Color.folioAccentLight : Color.clear)
            .overlay(
              RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                  isSelected ? Color.folioInk : Color.folioRowBorder,
                  lineWidth: 1
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(option.displayTitle)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
      .padding(.horizontal, FolioSpacing.xl2)
      .padding(.bottom, FolioSpacing.xl2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.folioSurfaceStrong)
    .presentationDetents([.height(FolioSize.sheetDefaultMin)])
    .presentationBackground(Color.folioSurfaceStrong)
    .presentationCornerRadius(FolioRadius.tabBar)
  }

  private var dragHandle: some View {
    Capsule()
      .fill(Color.folioInkSoft.opacity(0.3))
      .frame(width: 34, height: 4)
      .padding(.top, FolioSpacing.md)
      .padding(.bottom, FolioSpacing.md)
  }
}
