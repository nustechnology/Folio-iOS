import Foundation

enum AskSavedNoteFormatter {
    static let titleMaxLength = 150
    static let defaultTitle = String(localized: "Saved answer")

    static func formatTitle(from question: String) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let clamped = String(trimmed.prefix(titleMaxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clamped.isEmpty ? defaultTitle : clamped
    }

    static func formatContent(
        answer: String,
        limitation: String?,
        citations: [AskCitation]
    ) -> String {
        var parts: [String] = []
        parts.append(answer.trimmingCharacters(in: .whitespacesAndNewlines))

        if let limitation, !limitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("\nLimitation: \(limitation)")
        }

        if !citations.isEmpty {
            parts.append("\nEvidence")
            for citation in citations.sorted(by: { $0.index < $1.index }) {
                let location = citation.locationLabel.isEmpty ? "" : " — \(citation.locationLabel)"
                parts.append("\n[\(citation.index)] \(citation.sourceTitle)\(location)\n\(citation.evidenceText)")
            }
        }

        let content = parts.joined(separator: "\n")
        return String(content.prefix(NoteLimits.maximumContentLength))
    }

    static func formatCitationDTOs(from citations: [AskCitation]) -> [SavedAnswerCitationDTO] {
        citations.map { citation in
            SavedAnswerCitationDTO(
                sourceId: citation.sourceID,
                sourceTitle: citation.sourceTitle,
                snippet: citation.evidenceText,
                locationLabel: citation.locationLabel
            )
        }
    }
}
