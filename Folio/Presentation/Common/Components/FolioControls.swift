import SwiftUI

struct FolioCard<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .padding(16)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.folioLine.opacity(0.75), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 2)
    }
}

struct FolioPill: View {
    let title: String
    var isSelected: Bool = false
    var tint: Color = .folioGold

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isSelected ? Color.folioOliveDark : Color.folioInkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? tint.opacity(0.18) : Color.folioSurface)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.55) : Color.folioLine.opacity(0.7), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

struct FolioPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(Color.folioOliveDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioGold.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct FolioSecondaryButton: View {
    let title: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.folioInk)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.folioLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct FolioTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 14, weight: .regular))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if isSecure {
                Image("Eye")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.folioLine, lineWidth: 1)
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

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.folioInkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.folioSurface)
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
