import SwiftUI

struct EditSourceSheet: View {
    @Binding var title: String
    @Binding var author: String
    @Binding var content: String
    let sourceType: SourceType
    let isEditing: Bool
    let errorMessage: String?
    let maximumTitleLength: Int
    let maximumAuthorLength: Int
    let maximumContentLength: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, author, content
    }

    private var trimmedTitleCount: Int {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var trimmedAuthorCount: Int {
        author.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var trimmedContentCount: Int {
        content.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var isOverLimit: Bool {
        trimmedTitleCount > maximumTitleLength
            || trimmedAuthorCount > maximumAuthorLength
            || (sourceType == .manual && trimmedContentCount > maximumContentLength)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Edit source"))
                .font(.system(size: FolioFontSize.heading, weight: .regular, design: .serif))
                .foregroundStyle(Color.folioTextPrimary)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl5)
                .padding(.bottom, FolioSpacing.xs)

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.xl) {
                    titleField
                    authorField
                    if sourceType == .manual {
                        contentField
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: FolioFontSize.small))
                            .foregroundStyle(Color.folioDanger)
                    }
                    buttons
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.lg)
                .padding(.top, FolioSpacing.sm)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .presentationDetents(sourceType == .manual ? [.height(580)] : [.height(315)])
        .presentationDragIndicator(.visible)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Title"))
                .font(.system(size: FolioFontSize.body, weight: .bold))
                .foregroundStyle(Color.folioHomeTypeTextText)

            TextField(
                String(localized: "Title"),
                text: Binding(
                    get: { title },
                    set: { title = $0 }
                )
            )
            .font(.system(size: FolioFontSize.bodyLarge, weight: .regular))
            .foregroundStyle(Color.folioInk)
            .autocapitalization(.sentences)
            .focused($focusedField, equals: .title)
            .padding(.horizontal, FolioSpacing.xl)
            .frame(height: FolioSize.fieldHeightXs)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: FolioRadius.lg)
                    .stroke(trimmedTitleCount > maximumTitleLength ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg))

            HStack {
                if trimmedTitleCount > maximumTitleLength {
                    Text(String(localized: "Title cannot exceed \(maximumTitleLength) characters"))
                        .font(.system(size: FolioFontSize.small))
                        .foregroundStyle(Color.folioDanger)
                }
                Spacer()
                Text("\(trimmedTitleCount)/\(maximumTitleLength)")
                    .font(.system(size: FolioFontSize.small))
                    .foregroundStyle(trimmedTitleCount > maximumTitleLength ? Color.folioDanger : Color.folioInkSoft)
            }
        }
    }

    private var authorField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Author"))
                .font(.system(size: FolioFontSize.body, weight: .bold))
                .foregroundStyle(Color.folioHomeTypeTextText)

            TextField(
                String(localized: "Author"),
                text: Binding(
                    get: { author },
                    set: { author = $0 }
                )
            )
            .font(.system(size: FolioFontSize.bodyLarge, weight: .regular))
            .foregroundStyle(Color.folioInk)
            .autocapitalization(.words)
            .focused($focusedField, equals: .author)
            .padding(.horizontal, FolioSpacing.xl)
            .frame(height: FolioSize.fieldHeightXs)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: FolioRadius.lg)
                    .stroke(trimmedAuthorCount > maximumAuthorLength ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg))

            HStack {
                if trimmedAuthorCount > maximumAuthorLength {
                    Text(String(localized: "Author cannot exceed \(maximumAuthorLength) characters"))
                        .font(.system(size: FolioFontSize.small))
                        .foregroundStyle(Color.folioDanger)
                }
                Spacer()
                Text("\(trimmedAuthorCount)/\(maximumAuthorLength)")
                    .font(.system(size: FolioFontSize.small))
                    .foregroundStyle(trimmedAuthorCount > maximumAuthorLength ? Color.folioDanger : Color.folioInkSoft)
            }
        }
    }

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Content"))
                .font(.system(size: FolioFontSize.body, weight: .bold))
                .foregroundStyle(Color.folioHomeTypeTextText)

            TextEditor(text: Binding(
                get: { content },
                set: { content = $0 }
            ))
            .font(.system(size: FolioFontSize.bodyLarge, design: .default))
            .scrollContentBackground(.hidden)
            .padding(FolioSpacing.md)
            .frame(minHeight: 120, maxHeight: 200)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: FolioRadius.lg)
                    .stroke(trimmedContentCount > maximumContentLength ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.lg))
            .focused($focusedField, equals: .content)

            HStack {
                if trimmedContentCount > maximumContentLength {
                    Text(String(localized: "Content exceeds maximum limit of \(maximumContentLength) characters."))
                        .font(.system(size: FolioFontSize.small))
                        .foregroundStyle(Color.folioDanger)
                }
                Spacer()
                Text("\(trimmedContentCount.formatted())/\(maximumContentLength.formatted())")
                    .font(.system(size: FolioFontSize.small))
                    .foregroundStyle(trimmedContentCount > maximumContentLength ? Color.folioDanger : Color.folioInkSoft)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: FolioSpacing.lg) {
            Button {
                focusedField = nil
                dismiss()
                onCancel()
            } label: {
                Text(String(localized: "Cancel"))
                    .font(.system(size: FolioFontSize.bodyLarge, weight: .medium))
                    .foregroundStyle(Color.folioTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.md)
                            .stroke(Color.folioBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                    .contentShape(RoundedRectangle(cornerRadius: FolioRadius.md))
            }
            .buttonStyle(.plain)

            Button {
                focusedField = nil
                onConfirm()
            } label: {
                HStack(spacing: 6) {
                    if isEditing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(String(localized: "Save"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Color.folioOlive)
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                .contentShape(RoundedRectangle(cornerRadius: FolioRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(isEditing || isOverLimit)
        }
    }
}
