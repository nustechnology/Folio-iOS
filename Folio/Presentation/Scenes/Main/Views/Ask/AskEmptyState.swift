import SwiftUI

// MARK: - Empty state (mirrors AskEmptyState.kt)

struct AskEmptyStateHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.folioSurfaceStrong)
                    .overlay(Circle().stroke(Color.folioLine, lineWidth: 1))
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.folioGold)
            }
            Text("Ask a question")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.folioInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AskSuggestionCard: View {
    let text: String
    let enabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.folioInkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.folioLine, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

struct AskSuggestionCardSkeleton: View {
    private let placeholderColor = Color.folioBorderLight.opacity(0.5)

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(placeholderColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 15)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.folioLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shimmer()
            .accessibilityHidden(true)
    }
}

struct AskNoEvidenceBanner: View {
    var message: String? = nil
    let onAddSource: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message ?? String(localized: "No evidence available. Add a source before asking this question."))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.folioInkMuted)
            Button(action: onAddSource) {
                Text(String(localized: "Add a source"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.folioOliveDark)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.folioWarning.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
