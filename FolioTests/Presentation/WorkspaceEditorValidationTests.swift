import XCTest
@testable import Folio

final class WorkspaceEditorValidationTests: XCTestCase {
    func testDraftTruncatesNameAndObjectiveToEditorLimits() {
        let draft = WorkspaceEditorDraft(
            name: String(repeating: "n", count: 101),
            objective: String(repeating: "o", count: 501)
        )

        let limited = draft.limited

        XCTAssertEqual(limited.name.count, 100)
        XCTAssertEqual(limited.objective.count, 500)
    }

    func testSubmissionTrimsValuesAndRejectsWhitespaceOnlyName() {
        let valid = WorkspaceEditorDraft(name: "  Research  ", objective: "  Objective  ")
        let invalid = WorkspaceEditorDraft(name: " \n ", objective: "Objective")

        XCTAssertEqual(valid.submission, WorkspaceEditorSubmission(name: "Research", objective: "Objective"))
        XCTAssertNil(invalid.submission)
    }
}
