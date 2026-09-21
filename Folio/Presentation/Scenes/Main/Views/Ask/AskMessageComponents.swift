import SwiftUI

// MARK: - Message bubbles (mirrors AskMessageComponents.kt)

struct AskMessageBubble: View {
    let message: AskMessage
    let userAvatarLabel: String
    let isSavingNote: Bool
    let onCitationTap: (AskCitation) -> Void
    let onStop: () -> Void
    let onSaveAsNote: () -> Void
    let onFeedback: (Bool) -> Void

    var body: some View {
        switch message.role {
        case .user:
            AskUserBubble(message: message, userAvatarLabel: userAvatarLabel)
        case .assistant:
            if !message.isStreaming && message.content.isEmpty && message.limitation == nil && message.citations.isEmpty {
                EmptyView()
            } else {
                AskAssistantBubble(
                    message: message,
                    isSavingNote: isSavingNote,
                    onCitationTap: onCitationTap,
                    onStop: onStop,
                    onSaveAsNote: onSaveAsNote,
                    onFeedback: onFeedback
                )
            }
        }
    }
}

struct AskUserBubble: View {
    let message: AskMessage
    let userAvatarLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 40)
            Text(message.content)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.folioOliveDark)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            AskMessageAvatar(label: userAvatarLabel, background: Color.folioOliveDark, foreground: .white)
        }
    }
}

struct AskAssistantBubble: View {
    let message: AskMessage
    let isSavingNote: Bool
    let onCitationTap: (AskCitation) -> Void
    let onStop: () -> Void
    let onSaveAsNote: () -> Void
    let onFeedback: (Bool) -> Void

    @State private var isEvidenceExpanded = false

    private var showThinkingRow: Bool { message.isStreaming }
    private var showContent: Bool { !message.content.isEmpty }
    private var showToolbar: Bool { !message.isStreaming && showContent }
    private var showLimitation: Bool { !message.isStreaming && message.limitation != nil }
    private var showEvidence: Bool { !message.isStreaming && !message.citations.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AskMessageAvatar(label: String(localized: "AI"), background: Color(hex: 0xE3EDF7), foreground: Color.folioOliveDark)
            VStack(alignment: .leading, spacing: 10) {
                if showThinkingRow && !showContent {
                    AskThinkingStopRow(onStop: onStop)
                }
                if showContent {
                    Text(attributedAskContent(message.content))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.folioInk)
                        .tint(Color.folioOliveDark)
                        .environment(\.openURL, OpenURLAction { url in
                            guard url.scheme == "folio-citation", let index = Int(url.host ?? "") else {
                                return .systemAction
                            }
                            if let citation = resolveCitation(message.citations, index: index) {
                                onCitationTap(citation)
                            }
                            return .handled
                        })
                }
                if showThinkingRow && showContent {
                    AskThinkingStopRow(onStop: onStop)
                }
                if showLimitation, let limitation = message.limitation {
                    HStack {
                        (Text(String(localized: "Limitation: ")).bold() + Text(limitation))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(hex: 0x8C6B2D))
                            .lineSpacing(3)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xFDF4DB))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if showEvidence {
                    Rectangle()
                        .fill(Color.folioLine.opacity(0.6))
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Evidence"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.folioInkMuted)

                        let displayedCitations = isEvidenceExpanded ? message.citations : Array(message.citations.prefix(2))
                        ForEach(displayedCitations) { citation in
                            Button {
                                onCitationTap(citation)
                            } label: {
                                HStack {
                                    let labelText = citation.locationLabel.isEmpty
                                        ? "[\(citation.index)] \(citation.sourceTitle)"
                                        : "[\(citation.index)] \(citation.sourceTitle) -- \(citation.locationLabel)"
                                    Text(labelText)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.folioInk)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: 0xFDF4DB))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        if message.citations.count > 2 {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isEvidenceExpanded.toggle()
                                    }
                                } label: {
                                    Text(isEvidenceExpanded ? String(localized: "Show less") : String(localized: "Show more"))
                                        .font(.system(size: 13, weight: .regular).italic())
                                        .foregroundStyle(Color.folioInkMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if showToolbar {
                    AskResponseToolbar(
                        message: message,
                        isSavingNote: isSavingNote,
                        onSaveAsNote: onSaveAsNote,
                        onFeedback: onFeedback
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: 320, alignment: .leading)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.folioLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer(minLength: 40)
        }
    }
}

struct AskMessageAvatar: View {
    let label: String
    let background: Color
    let foreground: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(background)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
            .frame(width: 32, height: 32)
            .overlay(
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(foreground)
            )
    }
}

struct AskThinkingStopRow: View {
    let onStop: () -> Void

    var body: some View {
        HStack {
            Text("Thinking…")
                .font(.system(size: 14, weight: .regular).italic())
                .foregroundStyle(Color.folioInkMuted)
            Spacer()
            Button(action: onStop) {
                Text("Stop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.folioOliveDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.folioSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.folioLine, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

struct AskResponseToolbar: View {
    let message: AskMessage
    let isSavingNote: Bool
    let onSaveAsNote: () -> Void
    let onFeedback: (Bool) -> Void

    @State private var isFeedbackExpanded = false

    var body: some View {
        HStack {
            AskToolbarButton(
                title: message.isSavedAsNote ? "Saved" : (isSavingNote ? "Saving…" : "Save as note"),
                selected: message.isSavedAsNote,
                enabled: !message.isSavedAsNote && !isSavingNote,
                action: onSaveAsNote
            )

            Spacer()

            if isFeedbackExpanded || message.feedback != .none {
                HStack(spacing: 8) {
                    Text("Useful?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.folioInkMuted)

                    Button {
                        onFeedback(true)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFeedbackExpanded = false
                        }
                    } label: {
                        Text("Yes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(message.feedback == .useful ? Color.folioOliveDark : Color.folioInkMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(message.feedback == .useful ? Color.folioOliveDark.opacity(0.12) : Color.folioSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onFeedback(false)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFeedbackExpanded = false
                        }
                    } label: {
                        Text("No")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(message.feedback == .notUseful ? Color.folioDanger : Color.folioInkMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(message.feedback == .notUseful ? Color.folioDanger.opacity(0.12) : Color.folioSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFeedbackExpanded = true
                    }
                } label: {
                    Text("Useful?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.folioInkMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct AskToolbarButton: View {
    let title: String
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white : Color.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.folioOliveDark : Color.folioAccentLight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
    }
}
