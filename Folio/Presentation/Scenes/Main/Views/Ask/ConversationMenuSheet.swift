import SwiftUI

// MARK: - Conversation menu sheet (mirrors ConversationBottomSheet.kt)

struct ConversationMenuSheet: View {
    let onNewConversation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Conversation")
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)

            Button(action: onNewConversation) {
                Text("New conversation")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.folioOliveDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.height(150)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.white)
    }
}
