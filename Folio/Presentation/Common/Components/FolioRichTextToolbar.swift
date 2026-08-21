import SwiftUI

struct RichTextToolbar: View {
    enum Configuration: Equatable {
        case notebook
        case notes
    }

    struct ActiveFormats {
        let isBold: Bool
        let isItalic: Bool
        let isUnorderedList: Bool
        let isOrderedList: Bool
        let hasLink: Bool

        static let inactive = ActiveFormats(
            isBold: false,
            isItalic: false,
            isUnorderedList: false,
            isOrderedList: false,
            hasLink: false
        )
    }

    let onBold: () -> Void
    let onItalic: () -> Void
    let onHeading1: () -> Void
    let onHeading2: () -> Void
    let onHeading3: () -> Void
    let onUnorderedList: () -> Void
    let onOrderedList: () -> Void
    let onBlockquote: () -> Void
    let onHyperlink: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let canUndo: Bool
    let canRedo: Bool
    let saveStatus: SaveStatus
    let configuration: Configuration
    let activeFormats: ActiveFormats
    let isEmbedded: Bool

    enum SaveStatus: Equatable {
        case saved
        case saving
        case failed
    }

    init(
        onBold: @escaping () -> Void,
        onItalic: @escaping () -> Void,
        onHeading1: @escaping () -> Void,
        onHeading2: @escaping () -> Void,
        onHeading3: @escaping () -> Void,
        onUnorderedList: @escaping () -> Void,
        onOrderedList: @escaping () -> Void,
        onBlockquote: @escaping () -> Void,
        onHyperlink: @escaping () -> Void = {},
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        canUndo: Bool,
        canRedo: Bool,
        saveStatus: SaveStatus,
        configuration: Configuration = .notebook,
        activeFormats: ActiveFormats = .inactive,
        isEmbedded: Bool = false
    ) {
        self.onBold = onBold
        self.onItalic = onItalic
        self.onHeading1 = onHeading1
        self.onHeading2 = onHeading2
        self.onHeading3 = onHeading3
        self.onUnorderedList = onUnorderedList
        self.onOrderedList = onOrderedList
        self.onBlockquote = onBlockquote
        self.onHyperlink = onHyperlink
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.saveStatus = saveStatus
        self.configuration = configuration
        self.activeFormats = activeFormats
        self.isEmbedded = isEmbedded
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if configuration == .notebook {
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

                            toolbarDivider
                        }

                        FormatButton(glyph: "B", accessibilityText: String(localized: "Bold"), isActive: activeFormats.isBold, action: onBold)

                        FormatButton(glyph: "I", accessibilityText: String(localized: "Italic"), isActive: activeFormats.isItalic, action: onItalic)

                        if configuration == .notebook {
                            toolbarDivider

                            FormatButton(glyph: "H1", accessibilityText: String(localized: "Heading 1"), action: onHeading1)

                            FormatButton(glyph: "H2", accessibilityText: String(localized: "Heading 2"), action: onHeading2)

                            FormatButton(glyph: "H3", accessibilityText: String(localized: "Heading 3"), action: onHeading3)

                            toolbarDivider
                        }

                        FormatButton(systemImage: "list.bullet", accessibilityText: String(localized: "Unordered list"), isActive: activeFormats.isUnorderedList, action: onUnorderedList)

                        FormatButton(systemImage: "list.number", accessibilityText: String(localized: "Ordered list"), isActive: activeFormats.isOrderedList, action: onOrderedList)

                        if configuration == .notes {
                            FormatButton(glyph: "\u{1F517}", accessibilityText: String(localized: "Hyperlink"), isActive: activeFormats.hasLink, action: onHyperlink)
                        } else {
                            FormatButton(glyph: "\u{201C}", accessibilityText: String(localized: "Blockquote"), action: onBlockquote)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                if configuration == .notebook {
                    saveStatusBadge
                        .padding(.trailing, 8)
                }
            }
            .frame(height: 44)

            if !isEmbedded {
                Divider()
                    .background(Color.folioLine)
            }
        }
        .background(Color.folioSurfaceStrong)
    }

    private var toolbarDivider: some View {
        Color.folioLine.opacity(0.5)
            .frame(width: 1, height: 20)
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
    let glyph: String?
    let systemImage: String?
    let accessibilityText: String
    var isActive = false
    let action: () -> Void

    init(
        glyph: String,
        accessibilityText: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.glyph = glyph
        self.systemImage = nil
        self.accessibilityText = accessibilityText
        self.isActive = isActive
        self.action = action
    }

    init(
        systemImage: String,
        accessibilityText: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.glyph = nil
        self.systemImage = systemImage
        self.accessibilityText = accessibilityText
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else if let glyph {
                    Text(glyph)
                }
            }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.folioGold : Color.folioInk)
                .frame(width: 36, height: 36)
                .background(isActive ? Color.folioOliveDark : Color.folioCanvas.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
