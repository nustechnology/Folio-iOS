import SwiftUI

enum ToastStyle: Equatable {
    case success
    case error
}

struct ToastMessage: Equatable {
    let text: String
    let style: ToastStyle

    static func success(_ text: String) -> ToastMessage {
        ToastMessage(text: text, style: .success)
    }

    static func error(_ text: String) -> ToastMessage {
        ToastMessage(text: text, style: .error)
    }
}

struct ToastView: View {
    let message: String
    let style: ToastStyle
    let onDismiss: () -> Void

    private var backgroundColor: Color {
        switch style {
        case .success: Color.folioOliveDark
        case .error: Color.folioDanger
        }
    }

    private var borderColor: Color {
        switch style {
        case .success: Color.folioGold.opacity(0.4)
        case .error: Color.folioDanger.opacity(0.5)
        }
    }

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal, 34)
                .padding(.bottom, 40)
        }
        .task {
            try? await Task.sleep(nanoseconds: FolioDuration.toastDismiss)
            onDismiss()
        }
    }
}

extension View {
    func folioToast(message: Binding<ToastMessage?>) -> some View {
        overlay(alignment: .bottom) {
            if let msg = message.wrappedValue {
                ToastView(message: msg.text, style: msg.style) {
                    withAnimation(.easeOut(duration: FolioDuration.fast)) {
                        message.wrappedValue = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: FolioDuration.fast), value: message.wrappedValue)
    }
}
