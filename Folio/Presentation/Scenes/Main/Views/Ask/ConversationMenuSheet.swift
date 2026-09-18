import SwiftUI

// MARK: - Conversation menu sheet (mirrors ConversationBottomSheet.kt)

struct ConversationMenuSheet: View {
    let onNewConversation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Conversation")
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)

            FolioPrimaryButton(
                title: String(localized: "New conversation"),
                verticalPadding: 14,
                action: onNewConversation
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.height(150)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.white)
    }
}
