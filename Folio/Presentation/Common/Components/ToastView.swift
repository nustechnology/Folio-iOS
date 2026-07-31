import SwiftUI

struct ToastView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.folioOliveDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioGold.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal, 34)
                .padding(.bottom, 40)
        }
        .task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            onDismiss()
        }
    }
}

extension View {
    func folioToast(message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let msg = message.wrappedValue {
                ToastView(message: msg) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        message.wrappedValue = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: message.wrappedValue)
    }
}
