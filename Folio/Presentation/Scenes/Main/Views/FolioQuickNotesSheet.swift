import SwiftUI

struct FolioQuickNotesSheet: View {
    let spaceName: String
    let notes: [NoteSummary]
    let isLoading: Bool
    let onNoteTap: (NoteSummary) -> Void
    let onNewNote: () -> Void
    let onManageNotes: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.folioHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, 12)

            HStack {
                Text(String(localized: "Quick Notes"))
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(Color.folioInk)

                Spacer()

                Button(action: onNewNote) {
                    Text("+ \(String(localized: "New"))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.folioGold)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(Color.folioGold)
                Spacer()
            } else if notes.isEmpty {
                emptyState
            } else {
                notesList
            }

            notesFooter
                .padding(.bottom, 20)
        }
        .presentationBackground(Color.folioSurfaceStrong)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var notesList: some View {
        List {
            ForEach(notes) { note in
                Button(action: { onNoteTap(note) }) {
                    QuickNoteRow(note: note)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Color.folioInkSoft)

            Text(String(localized: "No notes"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.folioInkMuted)

            Spacer()
        }
    }

    private var notesFooter: some View {
        Button(action: onManageNotes) {
            HStack(spacing: 4) {
                Text(String(localized: "Manage notes"))
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.folioGold)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

private struct QuickNoteRow: View {
    let note: NoteSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: noteIcon)
                .font(.system(size: 14))
                .foregroundStyle(Color.folioGold)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(note.originType.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.folioInkSoft)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.folioCanvas.opacity(0.6))
                        .clipShape(Capsule(style: .continuous))

                    Text(note.updatedAt.miniRelativeLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.folioInkSoft)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.folioInkSoft)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.folioCanvas.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var noteIcon: String {
        switch note.originType {
        case .userCreated: return "note.text"
        case .savedAssistantAnswer: return "sparkle"
        }
    }
}

#Preview {
    FolioQuickNotesSheet(
        spaceName: "Research",
        notes: [
            NoteSummary(id: "1", researchSpaceId: "s1", title: "Research findings", originType: .userCreated, contentPreview: "Some content", createdAt: Date(), updatedAt: Date(), citationCount: nil),
            NoteSummary(id: "2", researchSpaceId: "s1", title: "Source notes", originType: .savedAssistantAnswer, contentPreview: "More content", createdAt: Date(), updatedAt: Date().addingTimeInterval(-3600), citationCount: 1)
        ],
        isLoading: false,
        onNoteTap: { _ in },
        onNewNote: {},
        onManageNotes: {},
        onDismiss: {}
    )
}
