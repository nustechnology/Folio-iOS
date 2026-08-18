import SwiftUI

struct FolioAskView: View {
    let onBackToSpaces: () -> Void
    var scopedSource: Source? = nil

    @State private var prompt = ""
    @State private var isLoading = false
    @State private var resultText: String?
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FolioContentHeader(
                    title: String(localized: "Ask"),
                    subtitle: String(localized: "Private research assistant"),
                    onBackToSpaces: onBackToSpaces,
                    onPlusTapped: nil,
                    searchText: .constant("")
                )

                if let scopedSource {
                    scopeBanner(source: scopedSource)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "Ask across your sources with grounded citations and traceable evidence."))
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(Color.folioInk)

                    TextEditor(text: $prompt)
                        .font(.system(size: 14, weight: .regular))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.folioSurfaceStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.folioLine, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    FolioPrimaryButton(title: isLoading ? "Asking…" : "Ask Folio", action: submitAsk)
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.folioGold)
                    }

                    if let resultText {
                        FolioCard(
                            content: Text(resultText)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.folioInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                    }
                }
                .padding(.horizontal, 18)

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Quick prompts"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.folioInkSoft)
                        .textCase(.uppercase)

                    VStack(spacing: 10) {
                        promptCard("What does Turing argue about machine thinking?")
                        promptCard("Compare the surveillance risks in these sources.")
                        promptCard("Extract the strongest citation for my summary.")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 26)
            }
        }
    }

    private func scopeBanner(source: Source) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.folioOliveDark)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Scoping to this source"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.folioInkMuted)
                Text(source.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.folioGold.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.folioGold.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 18)
    }

    private func promptCard(_ text: String) -> some View {
        FolioCard(
            content: Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }

    private func submitAsk() {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        errorText = nil
        resultText = nil
        Task {
            try? await Task.sleep(nanoseconds: FolioDuration.askMockDelay)
            isLoading = false
            resultText = "Based on your sources, Turing argues that the question \"Can machines think?\" is too ambiguous. He reframes it as an imitation game where a machine's ability to mimic human responses is the practical test of intelligence."
        }
    }
}

#Preview {
    FolioAskView(onBackToSpaces: {})
}
