import Foundation
import XCTest
@testable import Folio

@MainActor
final class SaveAskNoteSheetTests: XCTestCase {
    func testContentToSavePreservesRawDraftUntilEditorContentChanges() {
        let originalContent = "Answer\nLimitation: details"
        let editingModel = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: originalContent),
            publishingHTML: { _ in }
        )

        XCTAssertEqual(
            SaveAskNoteSheet.contentToSave(
                draftContent: originalContent,
                editingModel: editingModel
            ),
            originalContent
        )
        XCTAssertFalse(editingModel.hasUnsavedChanges)

        editingModel.textChanged(NSAttributedString(string: "Edited answer"))

        XCTAssertTrue(editingModel.hasUnsavedChanges)
        XCTAssertEqual(
            SaveAskNoteSheet.contentToSave(
                draftContent: originalContent,
                editingModel: editingModel
            ),
            editingModel.serializedContent
        )
    }
}
