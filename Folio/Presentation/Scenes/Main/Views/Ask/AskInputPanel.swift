import SwiftUI

// MARK: - Input panel (mirrors AskInputPanel.kt)

struct AskInputPanel: View {
    @Binding var query: String
    let hasEvidence: Bool
    let isStreaming: Bool
    let scopeChipLabel: String
    let onScopeTap: () -> Void
    let onSubmit: () -> Void

    var isScopeEnabled: Bool = true

    private var inputEnabled: Bool { hasEvidence && !isStreaming }
    private var canSubmit: Bool { inputEnabled && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $query)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.folioInk)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 50)
                .disabled(!inputEnabled)
                .overlay(alignment: .topLeading) {
                    if query.isEmpty {
                        Text("Ask a question…")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .opacity(inputEnabled ? 1 : 0.55)

            HStack {
                Button(action: onScopeTap) {
                    HStack(spacing: 6) {
                        Text(scopeChipLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.folioInk)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.folioInkMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color.folioHomeTypeFileBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!isScopeEnabled || isStreaming)
                .opacity(isScopeEnabled && !isStreaming ? 1 : 0.55)

                Spacer()

                Button(action: onSubmit) {
                    HStack(spacing: 5) {
                        Text("Ask")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(canSubmit ? 1 : 0.8))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.folioOliveDark.opacity(canSubmit ? 1 : 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.folioLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(inputEnabled ? 1 : 0.55)
    }
}
