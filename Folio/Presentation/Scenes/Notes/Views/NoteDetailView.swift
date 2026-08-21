import SwiftUI
import UIKit

struct NoteDetailView: View {
    let note: Note
    let onEdit: () -> Void
    let onConvert: () -> Void
    var onOpenSource: (String) -> Void = { _ in }
    var showsActions: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCitation: NoteCitation?

    static func citationMarkerNumbers(in content: String, citationCount: Int) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]"#) else { return [] }
        let range = NSRange(location: 0, length: (content as NSString).length)
        return regex.matches(in: content, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let number = Int((content as NSString).substring(with: match.range(at: 1))),
                  number > 0,
                  number <= citationCount
            else { return nil }
            return number
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.lg)

            HStack(alignment: .top, spacing: FolioSpacing.md) {
                Text(note.title)
                    .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
                    .foregroundStyle(Color.folioInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: FolioFontSize.body, weight: .medium))
                        .foregroundStyle(Color.folioInk)
                        .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                        .background(Color.folioHomeSheetBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                                .stroke(Color.folioHomeSheetHandle.opacity(0.8), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Close"))
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.xl3)

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.md) {
                    metadata

                    FolioCard(
                        content: CitationRichTextView(
                            content: note.content,
                            citationCount: note.citations.count,
                            onCitationTapped: { index in
                                selectedCitation = note.citations[index]
                            }
                        ),
                        height: 160
                    )

                    if showsActions {
                        actionButtons
                    }
                }
                .padding(.horizontal, FolioSpacing.xl3)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.noteDetailSheetMinH, maxHeight: FolioSize.noteDetailSheetMaxH)
        .presentationDragIndicator(.hidden)
        .sheet(item: $selectedCitation) { citation in
            CitationDetailSheet(
                citation: citation,
                onOpenSource: {
                    selectedCitation = nil
                    dismiss()
                    onOpenSource(citation.sourceId)
                }
            )
        }
    }

    private var metadata: some View {
        HStack(spacing: FolioSpacing.sm) {
            FolioKindBadge(
                title: note.originType.title,
                backgroundColor: Color.folioHomeTypeFileBackground,
                textColor: Color.folioHomeTypeFileText
            )

            if let citationCount = note.citationCount, note.hasCitations {
                FolioKindBadge(
                    title: citationCount.noteCitationDisplayLabel,
                    backgroundColor: Color.folioHomeTypeFileBackground,
                    textColor: Color.folioHomeTypeFileText
                )
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: FolioSpacing.xs) {
                detailDateRow(label: String(localized: "Updated"), date: note.updatedAt)
                detailDateRow(label: String(localized: "Created"), date: note.createdAt)
            }
        }
    }

    private func detailDateRow(label: String, date: Date) -> some View {
        HStack(spacing: FolioSpacing.xs) {
            Text("\(label) \(date.noteListDisplayLabel)")
                .font(.system(size: FolioFontSize.caption2, weight: .regular))
                .foregroundStyle(Color.folioInkMuted)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: FolioSpacing.lg) {
            FolioSecondaryButton(
                title: String(localized: "Convert to Source"),
                action: onConvert
            )

            FolioPrimaryButton(
                title: String(localized: "Edit"),
                action: onEdit
            )
        }
        .padding(.top, FolioSpacing.sm)
    }

}

struct CitationRichTextView: View {
    let content: String
    let citationCount: Int
    var onCitationTapped: (Int) -> Void = { _ in }

    var body: some View {
        CitationTextView(
            attributedText: Self.inlineAttributedString(content: content, citationCount: citationCount),
            onCitationTapped: onCitationTapped
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func inlineAttributedString(content: String, citationCount: Int) -> NSAttributedString {
        let attributed = NoteDisplayAttributedString.make(from: content)
        let string = attributed.string as NSString
        let fullRange = NSRange(location: 0, length: string.length)
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]"#) else {
            return attributed
        }

        let result = NSMutableAttributedString()
        var cursor = 0
        for match in regex.matches(in: string as String, range: fullRange) {
            if match.range.location > cursor {
                result.append(attributed.attributedSubstring(from: NSRange(
                    location: cursor,
                    length: match.range.location - cursor
                )))
            }
            guard match.numberOfRanges > 1,
                  let number = Int(string.substring(with: match.range(at: 1))),
                  number > 0,
                  number <= citationCount,
                  let url = URL(string: "folio-citation://\(number)")
            else {
                result.append(attributed.attributedSubstring(from: match.range))
                cursor = NSMaxRange(match.range)
                continue
            }
            result.append(NSAttributedString(
                string: "[\(number)]",
                attributes: [
                    .font: UIFont.systemFont(ofSize: FolioFontSize.caption2, weight: .semibold),
                    .foregroundColor: UIColor(Color.folioInk),
                    .backgroundColor: UIColor(Color.folioGold.opacity(0.3)),
                    .link: url
                ]
            ))
            cursor = NSMaxRange(match.range)
        }

        if cursor < string.length {
            result.append(attributed.attributedSubstring(from: NSRange(
                location: cursor,
                length: string.length - cursor
            )))
        }
        return result.length == 0 ? attributed : result
    }
}

private struct CitationTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let onCitationTapped: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCitationTapped: onCitationTapped)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.linkTextAttributes = [:]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onCitationTapped = onCitationTapped
        textView.attributedText = attributedText
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onCitationTapped: (Int) -> Void

        init(onCitationTapped: @escaping (Int) -> Void) {
            self.onCitationTapped = onCitationTapped
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            guard url.scheme == "folio-citation",
                  let host = url.host,
                  let number = Int(host),
                  number > 0
            else {
                return true
            }
            onCitationTapped(number - 1)
            return false
        }
    }
}
