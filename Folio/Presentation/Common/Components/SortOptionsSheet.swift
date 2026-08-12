import SwiftUI

struct SortOptionsSheet<Option: SortOption>: View {
    let title: String
    let options: [Option]
    let selectedValue: Option
    let onSelect: (Option) -> Void

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            Text(title)
                .font(.system(size: 24, design: .serif))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: option == selectedValue ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(
                                    option == selectedValue ? Color.folioOlive : Color.folioFieldBorder
                                )

                            Text(option.displayTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.folioInk)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                        .background(option == selectedValue ? Color.folioAccentLight : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(
                                    option == selectedValue ? Color.folioInk : Color.folioRowBorder,
                                    lineWidth: 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.displayTitle)
                    .accessibilityAddTraits(option == selectedValue ? .isSelected : [])
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.folioSurfaceStrong)
        .presentationDetents([.height(300)])
        .presentationBackground(Color.folioSurfaceStrong)
        .presentationCornerRadius(28)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.folioInkSoft.opacity(0.3))
            .frame(width: 34, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 10)
    }
}
