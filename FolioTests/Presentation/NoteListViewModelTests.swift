@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelTests: XCTestCase {
    func testOriginFilterShowsOnlySavedAnswersAfterLoading() async {
        let fetchNotes = FixtureNotesUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: fetchNotes,
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.onAppear)
        await fetchNotes.waitUntilRequestCount(reaches: 1)
        viewModel.handle(.filterSelected(.savedAnswers))
        await fetchNotes.waitUntilRequestCount(reaches: 2)

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["saved"])
    }

    func testNoteListDateInCurrentYearIncludesTime() {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: 10, minute: 42, second: 0, of: Date())!
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.dateFormat = "MMM dd, HH:mm"

        XCTAssertEqual(date.noteListDisplayLabel, formatter.string(from: date))
    }

    func testNoteListDateInDifferentYearIncludesYear() {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .year, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.dateFormat = "MMM dd, yyyy"

        XCTAssertEqual(date.noteListDisplayLabel, formatter.string(from: date))
    }

    func testZeroCitationsDisplaysNone() {
        XCTAssertEqual(0.noteCitationDisplayLabel, String(localized: "None"))
    }

    func testOneCitationUsesSingularLabel() {
        XCTAssertEqual(1.noteCitationDisplayLabel, String(localized: "1 Citation"))
    }

    func testMultipleCitationsUsesPluralLabel() {
        let expected = String.localizedStringWithFormat(String(localized: "%lld Citations"), Int64(3))
        XCTAssertEqual(3.noteCitationDisplayLabel, expected)
    }

    func testNoteHasCitationsOnlyForPositiveCitationCount() {
        XCTAssertTrue(makeNote(citationCount: 1).hasCitations)
        XCTAssertFalse(makeNote(citationCount: 0).hasCitations)
        XCTAssertFalse(makeNote(citationCount: nil).hasCitations)
    }
}
