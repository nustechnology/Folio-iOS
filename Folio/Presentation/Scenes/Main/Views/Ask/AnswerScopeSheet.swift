import SwiftUI

// MARK: - Answer scope sheet (mirrors AnswerScopeBottomSheet.kt)

struct AnswerScopeSheet: View {
    let selectedScope: AskScope
    let selectedSourceID: String?
    let sources: [FolioSource]
    let readySourceCount: Int
    let onSelect: (String?) -> Void

    @State private var query = ""

    private var readySources: [FolioSource] { sources.filter { $0.status == .ready } }

    private var filteredSources: [FolioSource] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return readySources }
        return readySources.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    private var showEntireSpace: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || String(localized: "Entire space").localizedCaseInsensitiveContains(trimmed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Answer scope")
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.folioInkSoft)
                TextField("Search sources", text: $query)
                    .font(.system(size: 15, weight: .regular))
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.folioSurfaceStrong)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.folioLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            ScrollView {
                VStack(spacing: 12) {
                    if showEntireSpace {
                        scopeOption(
                            title: String(localized: "Entire space"),
                            subtitle: String(format: String(localized: "%lld ready sources"), readySourceCount),
                            selected: selectedScope == .entireSpace,
                            action: { onSelect(nil) }
                        )
                    }
                    ForEach(filteredSources) { source in
                        scopeOption(
                            title: source.title,
                            subtitle: source.subtitle.isEmpty ? String(localized: "Source") : source.subtitle,
                            selected: selectedScope == .currentSource && selectedSourceID == source.id,
                            action: { onSelect(source.id) }
                        )
                    }
                    if !showEntireSpace && filteredSources.isEmpty {
                        Text("No matching sources")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.folioInkMuted)
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: 420)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.folioSurface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.folioSurface)
    }

    private func scopeOption(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(selected ? Color.folioGold : Color.folioLine)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(selected ? Color.folioGoldSoft.opacity(0.35) : Color.folioSurfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.folioGold : Color.folioLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
