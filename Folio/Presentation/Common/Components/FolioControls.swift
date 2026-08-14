import SwiftUI

struct FolioCard<Content: View>: View {
    let content: Content
    var height: CGFloat?

    var body: some View {
        if let height {
            ScrollView {
                content
                    .padding(FolioSpacing.xl)
            }
            .frame(height: height)
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                    .stroke(Color.folioLine.opacity(0.75), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: FolioRadius.md, y: 2)
        } else {
            content
                .padding(FolioSpacing.xl)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                        .stroke(Color.folioLine.opacity(0.75), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: FolioRadius.md, y: 2)
        }
    }
}

struct FolioPill: View {
    let title: String
    var isSelected: Bool = false
    var tint: Color = .folioGold
    var fontSize: CGFloat = FolioFontSize.small
    var backgroundColor: Color?

    var selectedBackground: Color {
        backgroundColor ?? tint.opacity(0.18)
    }

    var body: some View {
        Text(title)
            .font(.system(size: fontSize))
            .foregroundStyle(isSelected ? tint : Color.folioInk)
            .padding(.horizontal, FolioSpacing.lg2)
            .padding(.vertical, FolioSpacing.md)
            .background(isSelected ? selectedBackground : Color.folioSurface)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.55) : Color.folioLine.opacity(0.7), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

struct FolioPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var verticalPadding: CGFloat = 15
    let action: () -> Void

    private var isDisabled: Bool { isLoading || !isEnabled }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(isDisabled ? Color.white.opacity(0.55) : .white)
            .background(isDisabled ? Color.folioInkSoft.opacity(0.45) : Color.folioOliveDark)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isDisabled ? Color.folioBorder : Color.folioGold.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: isDisabled ? .clear : Color.black.opacity(0.08), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct FolioSecondaryButton: View {
    let title: String
    var iconName: String?
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.folioInk)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.folioFieldBorder, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

struct FolioDangerButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.folioDanger)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.folioDanger)
            .background(Color.folioDanger.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous)
                    .stroke(Color.folioDanger, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

struct FolioDestructiveFilledButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.folioDanger)
                .background(Color.folioDanger.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

struct FolioTextField: View {
    enum FieldStyle {
        case singleLine
        case multiline(minHeight: CGFloat = 100, maxHeight: CGFloat = 160)
    }

    var label: String?
    var placeholder: String = ""
    @Binding var text: String
    var style: FieldStyle = .singleLine
    var maxLength: Int?
    var isSecure: Bool = false
    var error: String?
    var keyboardType: UIKeyboardType = .default
    var focused: FocusState<Bool>.Binding?

    @State private var isPasswordVisible = false

    static func truncatedText(_ text: String, maxLength: Int?) -> String {
        guard let maxLength else { return text }
        return String(text.prefix(max(0, maxLength)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.folioHomeTypeTextText)
            }

            inputField

            if let maxLength {
                HStack {
                    Spacer()
                    Text("\(text.count)/\(maxLength)")
                        .font(.system(size: 11))
                        .foregroundStyle(text.count >= maxLength ? Color.folioDanger : Color.folioInkSoft)
                }
                .padding(.horizontal, 4)
            }

            if let error {
                Text(error)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.folioDanger)
                    .padding(.leading, 4)
            }
        }
        .onChange(of: text) { _, newValue in
            let truncatedText = Self.truncatedText(newValue, maxLength: maxLength)
            if truncatedText != newValue {
                text = truncatedText
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        switch style {
        case .singleLine:
            focusedInput(singleLineField)
        case let .multiline(minHeight, maxHeight):
            focusedInput(multilineField(minHeight: minHeight, maxHeight: maxHeight))
        }
    }

    private var singleLineField: some View {
        HStack {
            Group {
                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 14, weight: .regular))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(Color.folioInk)
            .keyboardType(keyboardType)

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .fieldStyle(error: error)
    }

    private func multilineField(minHeight: CGFloat, maxHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.folioInk)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.folioInkSoft.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .fieldStyle(error: error)
    }

    @ViewBuilder
    private func focusedInput<Content: View>(_ content: Content) -> some View {
        if let focused {
            content.focused(focused)
        } else {
            content
        }
    }
}

private extension View {
    func fieldStyle(error: String?) -> some View {
        background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(error != nil ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct FolioSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))

            TextField(placeholder, text: $text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color.folioOlive)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct FolioStatusBadge: View {
    let title: String
    let status: FolioSourceStatus

    var backgroundColor: Color {
        switch status {
        case .ready: return .folioSuccess.opacity(0.42)
        case .processing: return .folioWarning.opacity(0.48)
        case .failed: return .folioDanger.opacity(0.42)
        }
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.folioInkMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.folioLine.opacity(0.8), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

struct FolioKindBadge: View {
    let title: String
    let backgroundColor: Color
    let textColor: Color

    init(title: String, backgroundColor: Color = .folioSurface, textColor: Color = .folioInkSoft) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.folioLine.opacity(0.7), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

struct FolioCheckboxRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.folioOlive)
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.folioInk)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FolioEmptyStateView: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.folioGold)
                .frame(width: 68, height: 68)
                .background(Color.folioSurfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.folioLine, lineWidth: 1)
                )

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(Color.folioInk)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.folioInkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.folioLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FolioBackButton: View {
    let title: String
    var subtitle: String?
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if action != nil {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.folioInk)
                    }

                    Text(title)
                        .font(.custom("CormorantGaramond-Medium", size: 32))
                        .foregroundStyle(Color.folioGold)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
