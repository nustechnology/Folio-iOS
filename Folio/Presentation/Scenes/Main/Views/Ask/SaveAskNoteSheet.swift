import SwiftUI

// MARK: - Save as note sheet (mirrors SaveAskNoteBottomSheet.kt)

private struct PreferenceKeySaveNoteContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct SaveAskNoteSheet: View {
    let draft: SaveAskNoteDraft
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var title: String = ""
    @State private var showDiscardConfirm = false
    @State private var measuredHeight: CGFloat = 460
    @Environment(\.dismiss) private var dismiss

    private static let maxTitleLength = 150
    private static let maxNoteContentLength = 20_000
    private static let maxAnswerBoxHeight: CGFloat = 280

    private var titleTooLong: Bool { title.count > Self.maxTitleLength }
    private var titleModified: Bool { title != draft.initialTitle }

    private var fullFormattedAnswer: String {
        AskSavedNoteFormatter.formatContent(
            answer: draft.content,
            limitation: draft.limitation,
            citations: draft.citations
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save as note")
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)

            Text("Review the answer and adjust the title before saving it to this space.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.folioInk)

            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x966827))
                PlaceholderUITextField(
                    placeholder: String(localized: "Untitled Note"),
                    placeholderColor: UIColor(Color.folioInkSoft),
                    font: .systemFont(ofSize: 14, weight: .regular),
                    textColor: UIColor(Color.folioInk),
                    keyboardType: .default,
                    isSecureTextEntry: false,
                    text: $title
                )
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color.folioSurfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(titleTooLong ? Color.folioDanger : Color(hex: 0xC49859).opacity(0.7), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                if titleTooLong {
                    Text("Title cannot exceed 150 characters")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioDanger)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Answer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x966827))

                VStack(alignment: .trailing, spacing: 8) {
                    ScrollView {
                        Text(fullFormattedAnswer)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.folioInk)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: Self.maxAnswerBoxHeight)

                    Text("\(fullFormattedAnswer.count) / \(Self.maxNoteContentLength.formatted())")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                }
                .padding(14)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: 0xC49859).opacity(0.7), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 12) {
                Button {
                    if titleModified {
                        showDiscardConfirm = true
                    } else {
                        onCancel()
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.folioSurfaceStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.folioFieldBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onSubmit(title.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                } label: {
                    Text("Save note")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(titleTooLong ? 0.7 : 1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.folioOliveDark.opacity(titleTooLong ? 0.35 : 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(titleTooLong)
            }
        }
        .padding(24)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PreferenceKeySaveNoteContentHeight.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(PreferenceKeySaveNoteContentHeight.self) { height in
            if height > 0 {
                measuredHeight = height
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.folioSurface.ignoresSafeArea())
        .presentationDetents([.height(min(max(measuredHeight, 360), 720))])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.folioSurface)
        .onAppear { title = draft.initialTitle }
        .alert("Discard unsaved note?", isPresented: $showDiscardConfirm) {
            Button("Yes", role: .destructive) {
                onCancel()
                dismiss()
            }
            Button("No", role: .cancel) {}
        }
    }
}
