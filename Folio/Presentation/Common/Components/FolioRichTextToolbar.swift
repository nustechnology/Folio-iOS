import SwiftUI

struct RichTextToolbar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onHeading1: () -> Void
    let onHeading2: () -> Void
    let onHeading3: () -> Void
    let onUnorderedList: () -> Void
    let onOrderedList: () -> Void
    let onBlockquote: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let canUndo: Bool
    let canRedo: Bool
    let saveStatus: SaveStatus

    enum SaveStatus: Equatable {
        case saved
        case saving
        case failed
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        UndoRedoButton(
                            iconName: "arrow.uturn.backward",
                            label: String(localized: "Undo"),
                            isEnabled: canUndo,
                            action: onUndo
                        )

                        UndoRedoButton(
                            iconName: "arrow.uturn.forward",
                            label: String(localized: "Redo"),
                            isEnabled: canRedo,
                            action: onRedo
                        )

                        Color.folioLine.opacity(0.5)
                            .frame(width: 1, height: 20)

                        FormatButton(glyph: "B", accessibilityText: String(localized: "Bold"), action: onBold)

                        FormatButton(glyph: "I", accessibilityText: String(localized: "Italic"), action: onItalic)

                        Color.folioLine.opacity(0.5)
                            .frame(width: 1, height: 20)

                        FormatButton(glyph: "H1", accessibilityText: String(localized: "Heading 1"), action: onHeading1)

                        FormatButton(glyph: "H2", accessibilityText: String(localized: "Heading 2"), action: onHeading2)

                        FormatButton(glyph: "H3", accessibilityText: String(localized: "Heading 3"), action: onHeading3)

                        Color.folioLine.opacity(0.5)
                            .frame(width: 1, height: 20)

                        FormatButton(glyph: "•", accessibilityText: String(localized: "Unordered list"), action: onUnorderedList)

                        FormatButton(glyph: "1.", accessibilityText: String(localized: "Ordered list"), action: onOrderedList)

                        FormatButton(glyph: "\u{201C}", accessibilityText: String(localized: "Blockquote"), action: onBlockquote)
                    }
                    .padding(.horizontal, 8)
                }

                saveStatusBadge
                    .padding(.trailing, 8)
            }
            .frame(height: 44)

            Divider()
                .background(Color.folioLine)
        }
        .background(Color.folioSurfaceStrong)
    }

    private var saveStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(saveStatusColor)
                .frame(width: 6, height: 6)

            Text(saveStatusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.folioInkMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.folioCanvas.opacity(0.6))
        .clipShape(Capsule(style: .continuous))
    }

    private var saveStatusColor: Color {
        switch saveStatus {
        case .saved: return Color.folioSuccessStrong
        case .saving: return Color.folioGold
        case .failed: return Color.folioDanger
        }
    }

    private var saveStatusText: String {
        switch saveStatus {
        case .saved: return String(localized: "Saved")
        case .saving: return String(localized: "Saving…")
        case .failed: return String(localized: "Failed to save")
        }
    }
}

private struct FormatButton: View {
    let glyph: String
    let accessibilityText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.folioInk)
                .frame(width: 36, height: 36)
                .background(Color.folioCanvas.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }
}

private struct UndoRedoButton: View {
    let iconName: String
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isEnabled ? Color.folioInk : Color.folioInkSoft)
                .frame(width: 36, height: 36)
                .background(Color.folioCanvas.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

#Preview {
    VStack {
        RichTextToolbar(
            onBold: {},
            onItalic: {},
            onHeading1: {},
            onHeading2: {},
            onHeading3: {},
            onUnorderedList: {},
            onOrderedList: {},
            onBlockquote: {},
            onUndo: {},
            onRedo: {},
            canUndo: true,
            canRedo: false,
            saveStatus: .saved
        )
        Spacer()
    }
}
