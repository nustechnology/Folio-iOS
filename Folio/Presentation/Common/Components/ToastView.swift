import SwiftUI

enum ToastStyle: Equatable {
    case success
    case error
    case info
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

    static func info(_ text: String) -> ToastMessage {
        ToastMessage(text: text, style: .info)
    }
}

struct ToastView: View {
    let message: String
    let style: ToastStyle
    let onDismiss: () -> Void

    private var iconName: String {
        switch style {
        case .success: "checkmark"
        case .error: "exclamationmark.triangle"
        case .info: "info.circle"
        }
    }

    private var iconColor: Color {
        switch style {
        case .success: Color.folioHomeStatusReadyText
        case .error: Color.folioDanger
        case .info: Color.folioOlive
        }
    }

    private var iconBackgroundColor: Color {
        switch style {
        case .success: Color.folioHomeStatusReadyBackground
        case .error: Color.folioDanger.opacity(0.15)
        case .info: Color.folioAccentLight
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.folioHomeTextPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .task {
            try? await Task.sleep(nanoseconds: FolioDuration.toastDismiss)
            onDismiss()
        }
    }
}

extension View {
    func folioToast(message: Binding<ToastMessage?>) -> some View {
        overlay(alignment: .top) {
            if let msg = message.wrappedValue {
                ToastView(message: msg.text, style: msg.style) {
                    withAnimation(.easeOut(duration: FolioDuration.fast)) {
                        message.wrappedValue = nil
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: FolioDuration.fast), value: message.wrappedValue)
    }
}
