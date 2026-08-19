import SwiftUI

struct SourceReaderHeader: View {
    let source: Source
    var onBack: (() -> Void)?
    var headerTrailing: (() -> AnyView)?
    var infoTrailing: (() -> AnyView)?

    init(
        source: Source,
        onBack: (() -> Void)? = nil,
        headerTrailing: (() -> AnyView)? = nil,
        infoTrailing: (() -> AnyView)? = nil
    ) {
        self.source = source
        self.onBack = onBack
        self.headerTrailing = headerTrailing
        self.infoTrailing = infoTrailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.folioInk)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel(String(localized: "Back"))
                }

                Text(headerTitle)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                (headerTrailing?() ?? AnyView(EmptyView()))
                    .frame(width: FolioSize.tapTarget, height: FolioSize.tapTarget)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    typeBadge
                    statusBadge
                }
                Spacer(minLength: 0)
                (infoTrailing?() ?? AnyView(EmptyView()))
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            HStack(spacing: 6) {
                Text(authorText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(1)
                Text(String(localized: "·"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
                Text(addedLabel)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private var typeBadge: some View {
        Text(source.badgeText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(typeBadgeTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(typeBadgeBackground)
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
    }

    private var typeBadgeBackground: Color {
        switch source.sourceType {
        case .file: return Color.folioHomeTypeFileBackground
        case .web: return Color.folioHomeTypeWebBackground
        case .manual: return Color.folioHomeTypeTextBackground
        }
    }

    private var typeBadgeTextColor: Color {
        switch source.sourceType {
        case .file: return Color.folioHomeTypeFileText
        case .web: return Color.folioHomeTypeWebText
        case .manual: return Color.folioHomeTypeTextText
        }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(statusBackground)
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
    }

    private var statusText: String {
        switch source.processingState {
        case .ready: return String(localized: "Ready")
        case .failed: return String(localized: "Failed")
        case .added, .extractingText, .indexingEvidence: return String(localized: "Processing")
        }
    }

    private var statusColor: Color {
        switch source.processingState {
        case .ready: return Color.folioSuccessText
        case .failed: return Color.folioDanger
        case .added, .extractingText, .indexingEvidence: return Color.folioAmber
        }
    }

    private var statusBackground: Color {
        switch source.processingState {
        case .ready: return Color.folioSuccessLight
        case .failed: return Color.folioDanger.opacity(0.15)
        case .added, .extractingText, .indexingEvidence: return Color.folioAmberBg
        }
    }

    private var headerTitle: String {
        if source.sourceType == .file, !source.fileName.isEmpty {
            return source.fileName
        }
        let title = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? String(localized: "Untitled Source") : title
    }

    private var authorText: String {
        let author = source.author.trimmingCharacters(in: .whitespacesAndNewlines)
        return author.isEmpty ? String(localized: "Unknown Author") : author
    }

    private var addedLabel: String {
        let seconds = max(0, Date().timeIntervalSince(source.createdAt))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return String(localized: "Added just now") }
        if minutes < 60 { return String(localized: "Added \(minutes) mins ago") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "Added \(hours) hours ago") }
        let days = hours / 24
        if days < 7 { return String(localized: "Added \(days) days ago") }
        return String(localized: "Added") + " " + source.createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}
