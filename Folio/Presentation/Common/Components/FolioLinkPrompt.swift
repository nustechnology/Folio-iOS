import SwiftUI

struct FolioLinkPrompt: View {
    @Binding var url: String
    let error: String?
    let onCancel: () -> Void
    let onAdd: () -> Void

    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: FolioSpacing.xl3) {
                Text(String(localized: "Add link"))
                    .font(.system(size: FolioFontSize.headline, weight: .bold))
                    .foregroundStyle(Color.folioInk)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FolioTextField(
                    placeholder: String(localized: "Link URL"),
                    text: $url,
                    style: .singleLine,
                    error: error,
                    keyboardType: .URL,
                    focused: $isURLFieldFocused
                )

                HStack(spacing: FolioSpacing.sm) {
                    FolioSecondaryButton(
                        title: String(localized: "Cancel"),
                        action: onCancel
                    )

                    FolioPrimaryButton(
                        title: String(localized: "Add"),
                        verticalPadding: 14,
                        action: onAdd
                    )
                }
            }
            .padding(FolioSpacing.xl3)
            .frame(maxWidth: 320)
            .background(Color.folioHomeSheetBackground)
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xl2, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 24, y: 10)
            .onTapGesture {}
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            isURLFieldFocused = true
        }
    }

}
