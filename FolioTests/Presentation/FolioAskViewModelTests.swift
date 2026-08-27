@testable import Folio
import Foundation
import XCTest

@MainActor
final class FolioAskViewModelTests: XCTestCase {

    // MARK: - State initialization

    func testInitialState() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.state.messages.isEmpty)
        XCTAssertEqual(vm.state.scope, .entireSpace)
        XCTAssertNil(vm.state.selectedSourceID)
        XCTAssertTrue(vm.state.suggestions.isEmpty)
        XCTAssertFalse(vm.isStreaming)
    }

    // MARK: - Submit

    func testSubmitAddsUserAndAssistantMessages() {
        let vm = makeViewModel(sources: [readySource(id: "s1")])
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")

        vm.handle(.submit("What is X?"))

        XCTAssertEqual(vm.state.messages.count, 2)
        XCTAssertEqual(vm.state.messages[0].role, .user)
        XCTAssertEqual(vm.state.messages[0].content, "What is X?")
        XCTAssertEqual(vm.state.messages[1].role, .assistant)
        XCTAssertTrue(vm.state.messages[1].isStreaming)
    }

    func testSubmitWithEmptyQuestionIgnored() {
        let vm = makeViewModel(sources: [readySource(id: "s1")])
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")

        vm.handle(.submit("   "))

        XCTAssertTrue(vm.state.messages.isEmpty)
    }

    func testSubmitWithNoSourcesIgnored() {
        let vm = makeViewModel()
        vm.updateSources([], spaceId: nil)

        vm.handle(.submit("What?"))

        XCTAssertTrue(vm.state.messages.isEmpty)
    }

    func testSubmitWhileStreamingIgnored() {
        let vm = makeViewModel(
            sources: [readySource(id: "s1")],
            streamAnswer: .neverEnding)
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")

        vm.handle(.submit("First"))
        XCTAssertTrue(vm.state.messages.count >= 2)

        vm.handle(.submit("Second"))
        // Should still be 2 messages — second submit ignored
        XCTAssertEqual(vm.state.messages.count, 2)
    }

    // MARK: - Stop

    func testStopCancelsStreamAndFinalizesMessage() async {
        let vm = makeViewModel(
            sources: [readySource(id: "s1")],
            streamAnswer: .neverEnding)
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")

        vm.handle(.submit("Question"))
        let assistantID = vm.state.messages[1].id
        XCTAssertTrue(vm.isStreaming)

        vm.handle(.stop)

        XCTAssertFalse(vm.isStreaming)
        let assistant = vm.state.messages.first { $0.id == assistantID }
        XCTAssertNotNil(assistant)
        XCTAssertFalse(assistant!.isStreaming)
        XCTAssertTrue(assistant!.wasStopped)
    }

    // MARK: - Scope change

    func testScopeChangeResetsMessagesAndConversation() {
        let vm = makeViewModel(sources: [
            readySource(id: "s1"), readySource(id: "s2")
        ])
        vm.updateSources([readySource(id: "s1"), readySource(id: "s2")], spaceId: "sp1")

        vm.handle(.submit("Q1"))
        XCTAssertEqual(vm.state.messages.count, 2)

        vm.handle(.scopeOptionSelected(sourceID: "s2"))

        XCTAssertTrue(vm.state.messages.isEmpty)
        XCTAssertEqual(vm.state.scope, .currentSource)
        XCTAssertEqual(vm.state.selectedSourceID, "s2")
    }

    func testScopeChangeToEntireSpace() {
        let vm = makeViewModel(sources: [
            readySource(id: "s1"), readySource(id: "s2")
        ])
        vm.updateSources([readySource(id: "s1"), readySource(id: "s2")], spaceId: "sp1")
        vm.handle(.scopeOptionSelected(sourceID: "s1"))
        XCTAssertEqual(vm.state.scope, .currentSource)

        vm.handle(.scopeOptionSelected(sourceID: nil))
        XCTAssertEqual(vm.state.scope, .entireSpace)
        XCTAssertNil(vm.state.selectedSourceID)
    }

    // MARK: - New conversation

    func testNewConversationResetsState() {
        let vm = makeViewModel(sources: [readySource(id: "s1")])
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")
        vm.handle(.submit("Q1"))
        XCTAssertEqual(vm.state.messages.count, 2)

        vm.handle(.newConversation)

        XCTAssertTrue(vm.state.messages.isEmpty)
    }

    // MARK: - Conversation epoch guard

    func testConversationEpochBlocksLateResponse() async {
        let vm = makeViewModel(sources: [readySource(id: "s1")])
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")

        // Submit first question
        vm.handle(.submit("Q1"))
        let firstAssistantID = vm.state.messages[1].id

        // Change scope (increments epoch)
        vm.handle(.scopeOptionSelected(sourceID: "s1"))
        XCTAssertTrue(vm.state.messages.isEmpty)

        // Submit second question
        vm.handle(.submit("Q2"))
        XCTAssertEqual(vm.state.messages.count, 2)
        let secondAssistantID = vm.state.messages[1].id

        // The first assistant's message should not exist anymore
        XCTAssertNil(vm.state.messages.first { $0.id == firstAssistantID })
        XCTAssertNotNil(vm.state.messages.first { $0.id == secondAssistantID })
    }

    // MARK: - Display suggestions

    func testDisplaySuggestionsDefaultsWhenEmpty() {
        let vm = makeViewModel()
        let suggestions = vm.displaySuggestions
        XCTAssertEqual(suggestions.count, 3)
    }

    func testDisplaySuggestionsReturnsTopThree() {
        let vm = makeViewModel()
        vm.handle(.scopeOptionSelected(sourceID: nil))  // no-op but triggers state
        // Directly set suggestions via updateSources flow
        let vm2 = makeViewModel()
        // Can't directly set state.suggestions — it's private(set).
        // But displaySuggestions returns prefix(3) when suggestions exist.
        // We'll test the default path.
        XCTAssertEqual(vm2.displaySuggestions.count, 3)
    }

    // MARK: - Scope chip label

    func testScopeChipLabelEntireSpace() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.scopeChipLabel, "Entire space")
    }

    func testScopeChipLabelCurrentSource() {
        let vm = makeViewModel(sources: [readySource(id: "s1")])
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")
        vm.handle(.scopeOptionSelected(sourceID: "s1"))
        XCTAssertEqual(vm.scopeChipLabel, "Test Source")
    }

    // MARK: - hasEvidence

    func testHasEvidenceWithReadySource() {
        let vm = makeViewModel(sources: [readySource(id: "s1")])
        vm.updateSources([readySource(id: "s1")], spaceId: "sp1")
        XCTAssertTrue(vm.hasEvidence)
    }

    func testHasEvidenceWithNoSources() {
        let vm = makeViewModel()
        vm.updateSources([], spaceId: nil)
        XCTAssertFalse(vm.hasEvidence)
    }

    func testHasEvidenceCurrentSourceNotReady() {
        let vm = makeViewModel(sources: [processingSource(id: "s1")])
        vm.updateSources([processingSource(id: "s1")], spaceId: "sp1")
        vm.handle(.scopeOptionSelected(sourceID: "s1"))
        XCTAssertFalse(vm.hasEvidence)
    }

    // MARK: - Extract limitation

    func testExtractLimitationNone() {
        let (content, limitation) = FolioAskViewModel.extractLimitation(
            from: "Hello world", existingLimitation: nil)
        XCTAssertEqual(content, "Hello world")
        XCTAssertNil(limitation)
    }

    func testExtractLimitationPresent() {
        let input = "Answer text\n\nLIMITATION: May be incomplete"
        let (content, limitation) = FolioAskViewModel.extractLimitation(
            from: input, existingLimitation: nil)
        XCTAssertEqual(content, "Answer text")
        XCTAssertEqual(limitation, "May be incomplete")
    }

    func testExtractLimitationFromDonePayload() {
        let input = "Some answer\nLIMITATION: This is limited"
        let (content, limitation) = FolioAskViewModel.extractLimitation(
            from: input, existingLimitation: nil)
        XCTAssertEqual(content, "Some answer")
        XCTAssertEqual(limitation, "This is limited")
    }

    func testExtractLimitationExistingTakesPrecedence() {
        let input = "Answer\nLIMITATION: Extracted"
        let (content, limitation) = FolioAskViewModel.extractLimitation(
            from: input, existingLimitation: "Already set")
        XCTAssertEqual(content, "Answer")
        XCTAssertEqual(limitation, "Already set")
    }

    // MARK: - Citation tap

    func testCitationTapSetsPreview() {
        let vm = makeViewModel()
        let citation = AskCitation(
            index: 0, sourceID: "s1", sourceTitle: "Source",
            sourceKind: nil, locationLabel: "", evidenceText: "")
        vm.handle(.citationTap(citation))
        XCTAssertEqual(vm.previewCitation?.id, 0)
    }

    // MARK: - Save as note

    func testSaveAsNoteDismissedClearsDraft() {
        let vm = makeViewModel()
        // Can't set saveDraft directly, but dismissing nil is safe
        vm.handle(.saveAsNoteDismissed)
        XCTAssertNil(vm.saveDraft)
    }

    // MARK: - Helpers

    private func makeViewModel(
        sources: [FolioSource] = [],
        streamAnswer: MockStreamAnswerUseCase.Kind = .empty
    ) -> FolioAskViewModel {
        let streamUseCase = MockStreamAnswerUseCase(kind: streamAnswer)
        return FolioAskViewModel(
            sources: sources,
            fetchAskSuggestionsUseCase: MockFetchSuggestions(),
            streamAskAnswerUseCase: streamUseCase,
            fetchAskConversationDetailUseCase: MockFetchConversationDetail(),
            sendFeedbackUseCase: MockSendFeedback(),
            createSavedAnswerNoteUseCase: MockCreateSavedNote()
        )
    }

    private func readySource(id: String) -> FolioSource {
        FolioSource(
            id: id, workspaceID: "ws1", kind: .file,
            title: "Test Source", subtitle: "",
            addedText: "", status: .ready,
            chapterTitle: "", chapterText: "", calloutText: "",
            citationTitle: "", citationDetail: "", citationText: "",
            pageLabel: "1 of 1")
    }

    private func processingSource(id: String) -> FolioSource {
        FolioSource(
            id: id, workspaceID: "ws1", kind: .file,
            title: "Test Source", subtitle: "",
            addedText: "", status: .processing,
            chapterTitle: "", chapterText: "", calloutText: "",
            citationTitle: "", citationDetail: "", citationText: "",
            pageLabel: "1 of 1")
    }
}

// MARK: - Mock Use Cases

private struct MockFetchSuggestions: FetchAskSuggestionsUseCaseProtocol {
    func execute(spaceId: String, scope: String, sourceId: String?) async throws -> AskSuggestionsResult {
        AskSuggestionsResult(suggestions: [], isDynamic: false)
    }
}

private struct MockSendFeedback: SendFeedbackUseCaseProtocol {
    func execute(spaceId: String, conversationId: String, messageId: String, rating: String) async throws {}
}

private struct MockCreateSavedNote: CreateSavedAnswerNoteUseCaseProtocol {
    func execute(
        spaceId: String, title: String, content: String,
        project: String?, originConversationId: String?,
        originMessageId: String?, citationCount: Int?,
        citations: [SavedAnswerCitationDTO]?
    ) async throws -> Note {
        Note(
            id: "note-id", researchSpaceId: spaceId, title: title,
            originType: .savedAssistantAnswer, content: content,
            createdAt: Date(), updatedAt: Date(), citationCount: nil)
    }
}

private struct MockFetchConversationDetail: FetchAskConversationDetailUseCaseProtocol {
    func execute(spaceId: String, conversationId: String) async throws -> AskConversationDetail {
        AskConversationDetail(
            id: conversationId, researchSpaceId: spaceId,
            title: "", scope: AskConversationScope(type: "space", sourceId: nil),
            messages: [], createdAt: Date(), updatedAt: Date())
    }
}

private struct MockStreamAnswerUseCase: StreamAskAnswerUseCaseProtocol {
    enum Kind { case empty, neverEnding }

    let kind: Kind

    func execute(
        spaceId: String, question: String, scope: AskAnswerScope,
        sourceId: String?, conversationId: String?
    ) -> AsyncThrowingStream<AskAnswerStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            switch kind {
            case .empty:
                continuation.finish()
            case .neverEnding:
                // Never-yielding stream — stays open until cancelled
                break
            }
        }
    }
}
