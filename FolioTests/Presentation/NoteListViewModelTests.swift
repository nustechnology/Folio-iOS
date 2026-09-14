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

    func testCreateContentValidationRejectsHTMLWithNoPlainText() {
        let viewModel = makeViewModelForEditing()

        viewModel.handle(.createContentChanged("<p><br></p>"))
        XCTAssertNil(viewModel.state.createContentError)

        viewModel.handle(.createContentEditingEnded)
        XCTAssertEqual(viewModel.state.createContentError, String(localized: "Content cannot be empty"))
    }

    func testCreateContentChangeWaitsForEditingToEndBeforeValidatingEmptyBulletList() {
        let viewModel = makeViewModelForEditing()

        viewModel.handle(.createContentChanged("<ul><li></li></ul>"))
        XCTAssertNil(viewModel.state.createContentError)

        viewModel.handle(.createContentEditingEnded)
        XCTAssertEqual(viewModel.state.createContentError, String(localized: "Content cannot be empty"))
    }

    func testCreateContentChangeWaitsForEditingToEndBeforeValidatingEmptyNumberedList() {
        let viewModel = makeViewModelForEditing()

        viewModel.handle(.createContentChanged("<ol><li></li></ol>"))
        XCTAssertNil(viewModel.state.createContentError)

        viewModel.handle(.createContentEditingEnded)
        XCTAssertEqual(viewModel.state.createContentError, String(localized: "Content cannot be empty"))
    }

    func testEditContentValidationUsesPlainTextLength() {
        let viewModel = makeViewModelForEditing()
        let html = "<p>\(String(repeating: "x", count: NoteLimits.maximumContentLength + 1))</p>"

        viewModel.handle(.editContentChanged(html))
        viewModel.handle(.editContentEditingEnded)

        XCTAssertEqual(
            viewModel.state.editContentError,
            String.localizedStringWithFormat(
                String(localized: "Content exceeds maximum length of %@ characters"),
                NoteLimits.maximumContentLengthLabel
            )
        )
    }

    func testNoteValidationChecksTitleAndContentLimits() {
        let result = NoteLimits.validate(
            title: String(repeating: "t", count: NoteLimits.maximumTitleLength + 1),
            content: "<p>\(String(repeating: "c", count: NoteLimits.maximumContentLength + 1))</p>"
        )

        XCTAssertEqual(result.titleError, .titleTooLong)
        XCTAssertEqual(result.contentError, .contentTooLong)
    }

    func testNoteValidationUsesByteMessageForRawHTMLAndCharacterMessageForPlainText() {
        let rawHTMLResult = NoteLimits.validate(
            title: "Valid title",
            serializedContent: String(repeating: "x", count: NoteLimits.maximumRawHTMLLength + 1),
            plainText: "Valid content"
        )
        let plainTextResult = NoteLimits.validate(
            title: "Valid title",
            serializedContent: "<p>Valid content</p>",
            plainText: String(repeating: "x", count: NoteLimits.maximumContentLength + 1)
        )

        XCTAssertEqual(
            rawHTMLResult.contentError?.localizedMessage,
            String.localizedStringWithFormat(
                String(localized: "Content exceeds maximum size of %@ bytes"),
                NoteLimits.maximumRawHTMLLengthLabel
            )
        )
        XCTAssertEqual(
            plainTextResult.contentError?.localizedMessage,
            String.localizedStringWithFormat(
                String(localized: "Content exceeds maximum length of %@ characters"),
                NoteLimits.maximumContentLengthLabel
            )
        )
    }

    func testTitleValidationDoesNotRequireContent() {
        XCTAssertEqual(
            NoteLimits.validateTitle(String(repeating: "t", count: NoteLimits.maximumTitleLength + 1)),
            .titleTooLong
        )
        XCTAssertNil(NoteLimits.validateTitle("Valid title"))
    }

    func testCreateContentValidationAllowsMarkupBeyondPlainTextLimit() {
        let viewModel = makeViewModelForEditing()
        let plainText = String(repeating: "x", count: NoteLimits.maximumContentLength)
        let html = "<p style=\"font-family: 'Cormorant Garamond'; font-size: 32px; color: #123456;\">\(plainText)</p>"

        viewModel.handle(.createContentChanged(html))

        XCTAssertNil(viewModel.state.createContentError)
    }

    func testContentValidationCountsSerializedEntitiesAsDisplayedCharacters() {
        let viewModel = makeViewModelForEditing()
        let plainText = String(repeating: "x", count: NoteLimits.maximumContentLength - 1)
        let html = "<p>\(plainText)&#39;</p>"

        viewModel.handle(.createContentChanged(html))

        XCTAssertNil(viewModel.state.createContentError)
    }

    func testCitationMarkersMapToAvailableCitationIndexes() {
        XCTAssertEqual(
            NoteDetailView.citationMarkerNumbers(in: "Evidence [1] and [2] [9]", citationCount: 2),
            [1, 2]
        )
    }

    func testCitationInlineTextKeepsValidMarkersInOneStyledTextStream() {
        let attributed = CitationRichTextView.inlineAttributedString(
            content: "<p>A longer evidence sentence [1] continues after the marker.</p>",
            citationCount: 1
        )

        XCTAssertEqual(attributed.string, "A longer evidence sentence [1] continues after the marker.")

        let markerLocation = (attributed.string as NSString).range(of: "[1]").location
        XCTAssertNotNil(attributed.attribute(.backgroundColor, at: markerLocation, effectiveRange: nil))
    }

    func testNoteDisplayAttributedStringUnderlinesSupportedLinksAndPreservesURL() {
        let attributed = NoteDisplayAttributedString.make(
            from: "<p>Read <a href=\"https://example.com\">the paper</a>.</p>"
        )
        let linkRange = (attributed.string as NSString).range(of: "the paper")

        XCTAssertEqual(attributed.string, "Read the paper.")
        XCTAssertEqual(
            attributed.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL,
            URL(string: "https://example.com")
        )
        XCTAssertEqual(
            (attributed.attribute(.underlineStyle, at: linkRange.location, effectiveRange: nil) as? NSNumber)?.intValue,
            NSUnderlineStyle.single.rawValue
        )
    }

    private func makeViewModelForEditing() -> NoteListViewModel {
        NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
    }
}
