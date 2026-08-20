import Foundation
import UIKit

enum NotebookExportService {
    static func plainText(from attributedText: NSAttributedString) -> String {
        FolioRichTextEditor.attributedTextWithoutMarkers(attributedText).string
    }

    static func printableContent(from attributedText: NSAttributedString) -> NSAttributedString {
        FolioRichTextEditor.attributedTextWithoutMarkers(attributedText)
    }

    static func markdownExportURL(from attributedText: NSAttributedString, spaceName: String) -> URL? {
        let filename = sanitizedFilename("\(spaceName)-notebook.md")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try FolioRichTextEditor.markdownFromAttributedText(attributedText).write(
                to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            Logger.error("Markdown export failed: \(error)")
            return nil
        }
    }

    private static func sanitizedFilename(_ name: String) -> String {
        let invalidSet = CharacterSet(charactersIn: "/:<>\"\\|?*")
        return name.components(separatedBy: invalidSet).joined(separator: "-")
    }
}
