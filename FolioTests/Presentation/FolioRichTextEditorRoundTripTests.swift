@testable import Folio
import SwiftUI
import UIKit
import XCTest

final class FolioRichTextEditorRoundTripTests: XCTestCase {
    func testInlineToolbarLayoutDoesNotChangeRichTextSerialization() {
        let text = NSMutableAttributedString(string: "Note")
        text.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 16), range: NSRange(location: 0, length: text.length))

        XCTAssertEqual(
            FolioRichTextEditor.htmlFromAttributedText(text),
            "<p><em>Note</em></p>"
        )
    }

    func testFormattingDoesNotPublishWhenAttributedContentIsUnchanged() {
        let empty = FolioRichTextEditor.makeDefaultAttributedText()

        XCTAssertFalse(FolioRichTextEditor.shouldPublishContentChange(from: empty, to: empty))
        XCTAssertTrue(
            FolioRichTextEditor.shouldPublishContentChange(
                from: empty,
                to: NSAttributedString(string: "Note")
            )
        )
    }

    func testCoordinatorIgnoresSelectionChangesWhileUIViewIsSynchronizing() {
        var selectedRange = NSRange(location: 0, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let editor = FolioRichTextEditor(
            attributedText: .constant(NSAttributedString(string: "text")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        coordinator.isSynchronizingUIView = true

        let textView = UITextView()
        textView.selectedRange = NSRange(location: 2, length: 0)
        coordinator.textViewDidChangeSelection(textView)

        XCTAssertEqual(selectedRange, NSRange(location: 0, length: 0))
        XCTAssertTrue(typingAttributes.isEmpty)
    }

    func testCoordinatorUsesCurrentSelectionTypingAttributesWithoutStaleInlineBold() {
        var selectedRange = NSRange(location: 2, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [
            FolioRichTextFormat.inlineBoldAttribute: true
        ]
        let regularFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        let boldFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold)
        let attributedText = NSAttributedString(string: "plain", attributes: [.font: regularFont])
        let editor = FolioRichTextEditor(
            attributedText: .constant(attributedText),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
        textView.typingAttributes = [
            .font: boldFont,
            FolioRichTextFormat.inlineBoldAttribute: true
        ]

        coordinator.textViewDidChangeSelection(textView)

        XCTAssertNil(typingAttributes[FolioRichTextFormat.inlineBoldAttribute])
        XCTAssertEqual(typingAttributes[.font] as? UIFont, regularFont)
    }

    func testCoordinatorResetsTypingAttributesWhenAllTextIsDeleted() {
        var selectedRange = NSRange(location: 0, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.heading1FontSize),
            .foregroundColor: UIColor.clear,
            FolioRichTextFormat.inlineBoldAttribute: true
        ]
        let editor = FolioRichTextEditor(
            attributedText: .constant(NSAttributedString(string: "")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = NSAttributedString(string: "")
        textView.typingAttributes = typingAttributes

        coordinator.textViewDidChangeSelection(textView)

        XCTAssertEqual(
            (typingAttributes[.font] as? UIFont)?.pointSize,
            FolioRichTextFormat.bodyFontSize
        )
        XCTAssertFalse(typingAttributes[.foregroundColor] as? UIColor == .clear)
        XCTAssertNil(typingAttributes[FolioRichTextFormat.inlineBoldAttribute])
    }

    func testCoordinatorUsesBodyTypingAttributesWhenSelectingAnEmptyParagraph() {
        let headingFont = UIFont.systemFont(ofSize: FolioRichTextFormat.heading1FontSize)
        let text = NSMutableAttributedString(string: "Heading\n\n")
        text.addAttribute(.font, value: headingFont, range: NSRange(location: 0, length: text.length))
        var selectedRange = NSRange(location: text.length, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [.font: headingFont]
        let editor = FolioRichTextEditor(
            attributedText: .constant(text),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = text
        textView.selectedRange = selectedRange
        textView.typingAttributes = typingAttributes

        coordinator.textViewDidChangeSelection(textView)

        XCTAssertEqual(
            (typingAttributes[.font] as? UIFont)?.pointSize,
            FolioRichTextFormat.bodyFontSize
        )
    }

    func testCoordinatorUpdatesBindingsBeforePublishingTextChange() {
        var attributedText = NSAttributedString(string: "before")
        var selectedRange = NSRange(location: 0, length: 0)
        var publishedText: NSAttributedString?
        var publishedSelection: NSRange?
        let editor = FolioRichTextEditor(
            attributedText: Binding(get: { attributedText }, set: { attributedText = $0 }),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            onTextChange: { value in
                publishedText = value
                publishedSelection = selectedRange
            }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = NSAttributedString(string: "before\nafter")
        textView.selectedRange = NSRange(location: textView.attributedText.length, length: 0)

        coordinator.textViewDidChange(textView)

        XCTAssertEqual(publishedText, attributedText)
        XCTAssertEqual(publishedSelection, selectedRange)
        XCTAssertEqual(selectedRange, textView.selectedRange)
    }

    func testCoordinatorInsertsNewlineForPlainParagraphAtCaret() {
        let text = NSAttributedString(
            string: "before",
            attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
        )
        var attributedText = text
        var selectedRange = NSRange(location: text.length, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let editor = FolioRichTextEditor(
            attributedText: Binding(get: { attributedText }, set: { attributedText = $0 }),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = FolioTextView()
        textView.attributedText = text
        textView.selectedRange = selectedRange

        let handled = coordinator.textView(
            textView,
            shouldChangeTextIn: selectedRange,
            replacementText: "\n"
        )

        XCTAssertFalse(handled)
        XCTAssertEqual(textView.attributedText.string, "before\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: text.length + 1, length: 0))
    }

    func testCoordinatorPreservesInlineBoldFromCurrentHeadingSelection() {
        var selectedRange = NSRange(location: 0, length: 7)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let headingFont = UIFont.systemFont(
            ofSize: FolioRichTextFormat.heading1FontSize,
            weight: FolioRichTextFormat.inlineBoldFontWeight
        )
        let attributedText = NSAttributedString(
            string: "Heading",
            attributes: [
                .font: headingFont,
                FolioRichTextFormat.inlineBoldAttribute: true
            ]
        )
        let editor = FolioRichTextEditor(
            attributedText: .constant(attributedText),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
        textView.typingAttributes = [.font: headingFont]

        coordinator.textViewDidChangeSelection(textView)

        XCTAssertEqual(
            typingAttributes[FolioRichTextFormat.inlineBoldAttribute] as? Bool,
            true
        )
        XCTAssertEqual(
            textView.typingAttributes[FolioRichTextFormat.inlineBoldAttribute] as? Bool,
            true
        )
    }

    func testCoordinatorPreservesInlineBoldAtCaretFromCurrentHeadingText() {
        var selectedRange = NSRange(location: 7, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let headingFont = UIFont.systemFont(
            ofSize: FolioRichTextFormat.heading1FontSize,
            weight: FolioRichTextFormat.inlineBoldFontWeight
        )
        let attributedText = NSAttributedString(
            string: "Heading",
            attributes: [
                .font: headingFont,
                FolioRichTextFormat.inlineBoldAttribute: true
            ]
        )
        let editor = FolioRichTextEditor(
            attributedText: .constant(attributedText),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
        textView.typingAttributes = [.font: headingFont]

        coordinator.textViewDidChangeSelection(textView)

        XCTAssertEqual(
            typingAttributes[FolioRichTextFormat.inlineBoldAttribute] as? Bool,
            true
        )
    }

    func testCoordinatorDoesNotUseBoldAttributeFromPreviousParagraphNewline() {
        var selectedRange = NSRange(location: 5, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let boldFont = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold)
        let attributedText = NSMutableAttributedString(
            string: "bold\n",
            attributes: [
                .font: boldFont,
                FolioRichTextFormat.inlineBoldAttribute: true
            ]
        )
        let editor = FolioRichTextEditor(
            attributedText: .constant(attributedText),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        ]

        coordinator.textViewDidChangeSelection(textView)

        XCTAssertNil(typingAttributes[FolioRichTextFormat.inlineBoldAttribute])
    }

    func testCoordinatorUsesBodyTypingAttributesInsideAnEmptyBlockquote() {
        var selectedRange = NSRange(location: 2, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let text = NSMutableAttributedString(
            string: FolioRichTextFormat.blockquoteMarker,
            attributes: [
                .font: UIFont.systemFont(ofSize: FolioRichTextFormat.hiddenMarkerFontSize),
                .foregroundColor: UIColor.clear
            ]
        )
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.blockquoteIndent
        style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        let editor = FolioRichTextEditor(
            attributedText: .constant(text),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = FolioTextView()
        textView.attributedText = text
        textView.selectedRange = selectedRange
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: FolioRichTextFormat.hiddenMarkerFontSize),
            .foregroundColor: UIColor.clear
        ]

        coordinator.textViewDidChangeSelection(textView)

        let font = typingAttributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.bodyFontSize)
        XCTAssertFalse(typingAttributes[.foregroundColor] as? UIColor == .clear)
    }

    func testCoordinatorClearsLinkTypingAttributeAfterSpace() {
        var selectedRange = NSRange(location: 6, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [.link: URL(string: "https://example.com")!]
        let editor = FolioRichTextEditor(
            attributedText: .constant(NSAttributedString(string: "linked")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        let linkedText = NSMutableAttributedString(string: "linked")
        linkedText.addAttributes(typingAttributes, range: NSRange(location: 0, length: linkedText.length))
        textView.attributedText = linkedText
        textView.selectedRange = NSRange(location: linkedText.length, length: 0)
        textView.typingAttributes = typingAttributes
        XCTAssertNotNil(textView.typingAttributes[.link])

        XCTAssertTrue(
            coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 6, length: 0),
                replacementText: " "
            )
        )

        XCTAssertNil(textView.typingAttributes[.link])
        XCTAssertNil(typingAttributes[.link])
    }

    func testCoordinatorClearsLinkTypingAttributeAfterReturn() {
        var selectedRange = NSRange(location: 6, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [.link: URL(string: "https://example.com")!]
        let editor = FolioRichTextEditor(
            attributedText: .constant(NSAttributedString(string: "linked")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        let linkedText = NSMutableAttributedString(string: "linked")
        linkedText.addAttributes(typingAttributes, range: NSRange(location: 0, length: linkedText.length))
        textView.attributedText = linkedText
        textView.selectedRange = NSRange(location: linkedText.length, length: 0)
        textView.typingAttributes = typingAttributes

        XCTAssertTrue(
            coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 6, length: 0),
                replacementText: "\n"
            )
        )

        XCTAssertNil(textView.typingAttributes[.link])
        XCTAssertNil(typingAttributes[.link])
    }

    func testEditorSynchronizesSelectionWhenContentIsAlreadyInSync() {
        XCTAssertTrue(
            FolioRichTextEditor.shouldSynchronizeSelection(
                current: NSRange(location: 0, length: 0),
                desired: NSRange(location: 4, length: 0),
                textLength: 4
            )
        )
    }

    func testTypedBlockquoteMarkerIsNotTreatedAsBlockquote() {
        let text = NSAttributedString(string: "> hello\n")
        let html = FolioRichTextEditor.htmlFromAttributedText(text)
        XCTAssertFalse(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("&gt; hello"))
    }

    func testRealBlockquoteRoundTripsToBlockquote() {
        let mutable = NSMutableAttributedString(string: "> cited text\n")
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.blockquoteIndent
        style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        mutable.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: mutable.length))

        let html = FolioRichTextEditor.htmlFromAttributedText(mutable)

        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)
        XCTAssertTrue(html.contains("<blockquote>cited text</blockquote>"))
        XCTAssertTrue(parsed.string.contains(FolioRichTextFormat.blockquoteMarker))
    }

    func testEmptyBlockquoteKeepsItsMarker() {
        let html = "<blockquote></blockquote>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertTrue(parsed.string.contains(FolioRichTextFormat.blockquoteMarker))

        let reserialized = FolioRichTextEditor.htmlFromAttributedText(parsed)
        XCTAssertTrue(reserialized.contains("<blockquote>"))
    }

    func testBlockquoteMarkerIsInvisibleWithoutAddingContentIndentation() throws {
        let textView = makeLaidOutTextView(
            width: 180,
            text: quotedAttributedText("quoted content")
        )

        textView.applyBlockquotePresentation()

        let markerColor = try XCTUnwrap(
            textView.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        )
        let style = try XCTUnwrap(
            textView.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        let firstGlyph = textView.layoutManager.glyphIndexForCharacter(at: 2)
        let firstContentRect = textView.layoutManager.location(forGlyphAt: firstGlyph)

        XCTAssertEqual(textView.text, "> quoted content")
        XCTAssertEqual(markerColor, .clear)
        XCTAssertEqual(firstContentRect.x, style.headIndent, accuracy: 0.5)
    }

    func testBlockquoteMarkerIsExcludedFromAccessibilityLabel() {
        let textView = makeLaidOutTextView(
            width: 180,
            text: quotedAttributedText("quoted content")
        )

        textView.applyBlockquotePresentation()

        XCTAssertEqual(textView.accessibilityLabel, "quoted content")
    }

    func testEmptyBlockquoteKeepsCaretLineHeightAfterMarkerIsHidden() {
        let textView = makeLaidOutTextView(
            width: 180,
            text: quotedAttributedText("")
        )

        textView.applyBlockquotePresentation()

        let markerFont = textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertGreaterThanOrEqual(markerFont?.lineHeight ?? 0, UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize).lineHeight * 0.9)
    }

    func testAdjacentBlockquoteParagraphsShareOneVerticalRule() {
        let textView = makeLaidOutTextView(
            width: 180,
            text: quotedAttributedText("first\nsecond")
        )

        XCTAssertEqual(textView.blockquoteRuleRects().count, 1)
    }

    func testNormalParagraphSeparatesBlockquoteVerticalRules() {
        let textView = makeLaidOutTextView(
            width: 180,
            text: quotedThenPlainThenQuotedText()
        )

        XCTAssertEqual(textView.blockquoteRuleRects().count, 2)
    }

    func testWrappedBlockquoteRuleSpansAllVisualLines() throws {
        let textView = makeLaidOutTextView(
            width: 120,
            text: quotedAttributedText(String(repeating: "long quote ", count: 12))
        )

        let rule = try XCTUnwrap(textView.blockquoteRuleRects().first)
        let font = try XCTUnwrap(textView.font)

        XCTAssertGreaterThan(rule.height, font.lineHeight)
    }

    func testBlockquotePresentationDoesNotChangeHTMLSerialization() {
        let textView = makeLaidOutTextView(width: 180, text: quotedAttributedText("quoted"))

        textView.applyBlockquotePresentation()

        XCTAssertEqual(
            FolioRichTextEditor.htmlFromAttributedText(textView.attributedText),
            "<blockquote>quoted</blockquote>"
        )
        XCTAssertFalse(textView.text.contains("|"))
    }

    func testTypingAfterContinuingBlockquoteUsesBodyFont() {
        var selectedRange = NSRange(location: 0, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let editor = FolioRichTextEditor(
            attributedText: .constant(quotedAttributedText("quoted")),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = FolioTextView()
        textView.attributedText = quotedAttributedText("quoted")
        textView.selectedRange = NSRange(location: textView.attributedText.length, length: 0)

        XCTAssertFalse(coordinator.textView(
            textView,
            shouldChangeTextIn: textView.selectedRange,
            replacementText: "\n"
        ))

        let insertionRange = textView.selectedRange
        let typedText = NSAttributedString(string: "next", attributes: textView.typingAttributes)
        textView.textStorage.replaceCharacters(in: insertionRange, with: typedText)

        let font = textView.attributedText.attribute(.font, at: insertionRange.location, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, FolioRichTextFormat.bodyFontSize)
    }

    @MainActor
    func testNewlineInsideBlockquoteMarkerIsNotInsertedManually() {
        let text = quotedAttributedText("quoted")
        let editor = FolioRichTextEditor(
            attributedText: .constant(text),
            selectedRange: .constant(NSRange(location: 1, length: 0)),
            onTextChange: { _ in }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = text
        textView.selectedRange = NSRange(location: 1, length: 0)

        XCTAssertFalse(
            coordinator.textView(
                textView,
                shouldChangeTextIn: textView.selectedRange,
                replacementText: "\n"
            )
        )
        XCTAssertEqual(textView.attributedText.string, text.string)
    }

    func testParagraphRoundTrips() {
        let text = NSAttributedString(string: "plain paragraph\n")
        let html = FolioRichTextEditor.htmlFromAttributedText(text)
        XCTAssertTrue(html.contains("<p>plain paragraph</p>"))
    }

    func testTrailingNewlineSerializesAsAnEmptyParagraph() {
        let text = NSAttributedString(string: "hello\n")

        XCTAssertEqual(
            FolioRichTextEditor.htmlFromAttributedText(text),
            "<p>hello</p>\n<p></p>"
        )
    }

    @MainActor
    func testHandledListEditPublishesBeforeUpdatingBinding() {
        var publishedHTML: String?
        let model = NoteRichTextEditingModel(
            attributedText: NSAttributedString(string: "\u{2022}\tfirst"),
            publishingHTML: { publishedHTML = $0 }
        )
        var selectedRange = NSRange(location: model.attributedText.length, length: 0)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        let editor = FolioRichTextEditor(
            attributedText: Binding(get: { model.attributedText }, set: { model.attributedText = $0 }),
            selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
            typingAttributes: Binding(get: { typingAttributes }, set: { typingAttributes = $0 }),
            onTextChange: { model.textChanged($0) }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = model.attributedText
        textView.selectedRange = selectedRange

        XCTAssertFalse(
            coordinator.textView(
                textView,
                shouldChangeTextIn: selectedRange,
                replacementText: "\n"
            )
        )
        XCTAssertEqual(publishedHTML, FolioRichTextEditor.htmlFromAttributedText(model.attributedText))
    }

    func testOrderedListWithBoldAndItalicKeepsBoldOnParse() {
        let html = "<ol><li><em>Hello</em></li><li><strong>world</strong></li>"
            + "<li><strong>Hi</strong></li><li>what</li><li>Are <strong>you</strong></li></ol>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertTrue(parsed.string.contains("Hello"))
        XCTAssertTrue(parsed.string.contains("world"))

        func isBold(characterAt index: Int) -> Bool {
            guard index < parsed.length else { return false }
            guard let font = parsed.attribute(.font, at: index, effectiveRange: nil) as? UIFont else {
                return false
            }
            return font.fontDescriptor.symbolicTraits.contains(.traitBold)
        }

        let helloRange = (parsed.string as NSString).range(of: "Hello")
        let worldRange = (parsed.string as NSString).range(of: "world")
        let hiRange = (parsed.string as NSString).range(of: "Hi")

        // "Hello" should be italic, not bold.
        XCTAssertFalse(isBold(characterAt: helloRange.location))
        // "world" and "Hi" should be bold.
        XCTAssertTrue(isBold(characterAt: worldRange.location))
        XCTAssertTrue(isBold(characterAt: hiRange.location))
    }

    func testHeadingsUseDistinctWeightsFromInlineBold() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML(
            "<h1>One</h1><h2>Two</h2><h3>Three</h3><p><strong>Bold</strong></p>"
        )

        func fontName(of text: String) -> String? {
            let range = (parsed.string as NSString).range(of: text)
            guard range.location != NSNotFound,
                  let font = parsed.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont else {
                return nil
            }
            return font.fontDescriptor.postscriptName
        }

        XCTAssertEqual(fontName(of: "One"), UIFont.systemFont(ofSize: FolioRichTextFormat.heading1FontSize, weight: .semibold).fontDescriptor.postscriptName)
        XCTAssertEqual(fontName(of: "Two"), UIFont.systemFont(ofSize: FolioRichTextFormat.heading2FontSize, weight: .medium).fontDescriptor.postscriptName)
        XCTAssertEqual(fontName(of: "Three"), UIFont.systemFont(ofSize: FolioRichTextFormat.heading3FontSize, weight: .regular).fontDescriptor.postscriptName)
        XCTAssertEqual(fontName(of: "Bold"), UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold).fontDescriptor.postscriptName)
    }

    @MainActor
    func testApplyingH2AndH3PersistsAsSemanticHeadings() {
        let controller = RichTextFormattingController()

        for (text, fontSize, tag) in [("H2 text", FolioRichTextFormat.heading2FontSize, "h2"), ("H3 text", FolioRichTextFormat.heading3FontSize, "h3")] {
            let source = NSAttributedString(
                string: text,
                attributes: [.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]
            )
            let result = controller.applyHeading(
                fontSize: fontSize,
                in: source,
                selectedRange: NSRange(location: 0, length: source.length)
            )!

            let html = FolioRichTextEditor.htmlFromAttributedText(result.attributedText)
            let reopened = FolioRichTextEditor.attributedTextFromHTML(html)

            XCTAssertTrue(html.contains("<\(tag)>"), "Serialized HTML: \(html)")
            XCTAssertTrue(html.contains("</\(tag)>"), "Serialized HTML: \(html)")
            XCTAssertEqual(reopened.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
                           UIFont.systemFont(ofSize: fontSize, weight: FolioRichTextFormat.headingFontWeight(for: fontSize)))
        }
    }

    func testEditorSavePreservesBoldAndItalicInOrderedList() {
        // Simulate an ordered list as the editor holds it in memory:
        // "1.\tHello(italic)\n2.\tworld(bold)\n3.\tHi(bold)\n4.\twhat\n5.\tAre you(bold)\n"
        let text = "1.\tHello\n2.\tworld\n3.\tHi\n4.\twhat\n5.\tAre you\n"
        let mutable = NSMutableAttributedString(string: text)
        let italicBody = UIFont.italicSystemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        let boldBody = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize, weight: .bold)
        let attrs = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)]

        // Markers get body font.
        mutable.setAttributes(attrs, range: NSRange(location: 0, length: text.count))
        let helloRange = (text as NSString).range(of: "Hello")
        mutable.addAttribute(.font, value: italicBody, range: helloRange)
        let worldRange = (text as NSString).range(of: "world")
        mutable.addAttribute(.font, value: boldBody, range: worldRange)
        let hiRange = (text as NSString).range(of: "Hi")
        mutable.addAttribute(.font, value: boldBody, range: hiRange)
        let youRange = (text as NSString).range(of: "you")
        mutable.addAttribute(.font, value: boldBody, range: youRange)

        let html = FolioRichTextEditor.htmlFromAttributedText(mutable)

        XCTAssertTrue(html.contains("<strong>world</strong>"), "Serialized HTML: \(html)")
        XCTAssertTrue(html.contains("<em>Hello</em>"))
        XCTAssertTrue(html.contains("<strong>you</strong>"))
    }

    func testParseNestedEmStrongKeepsBoldAndItalic() {
        // Exactly the HTML from the GET response: <em><strong>Hello</strong></em>
        let html = "<ol><li><em><strong>Hello</strong></em></li><li><strong>world</strong></li>"
            + "<li><strong>Hi</strong></li><li>what</li><li>Are <strong>you</strong></li></ol>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        let helloRange = (parsed.string as NSString).range(of: "Hello")
        XCTAssertNotEqual(helloRange.location, NSNotFound)

        guard let font = parsed.attribute(.font, at: helloRange.location, effectiveRange: nil) as? UIFont else {
            XCTFail("No font on Hello")
            return
        }
        let traits = font.fontDescriptor.symbolicTraits
        XCTAssertTrue(traits.contains(.traitBold), "Hello should be bold, traits=\(traits)")
        XCTAssertTrue(traits.contains(.traitItalic), "Hello should be italic, traits=\(traits)")
    }

    func testOrderedListWithBoldAndItalicRoundTrips() {
        let html = "<ol><li><em>Hello</em></li><li><strong>world</strong></li>"
            + "<li><strong>Hi</strong></li><li>what</li><li>Are <strong>you</strong></li></ol>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)
        let reserialized = FolioRichTextEditor.htmlFromAttributedText(parsed)

        XCTAssertTrue(reserialized.contains("<strong>world</strong>"))
        XCTAssertTrue(reserialized.contains("<em>Hello</em>"))
        XCTAssertTrue(reserialized.contains("<strong>Hi</strong>"))
    }

    func testBulletListRoundTripsToSemanticHTML() {
        let html = "<ul><li>first</li><li><strong>second</strong></li></ul>"

        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)
        let reserialized = FolioRichTextEditor.htmlFromAttributedText(parsed)

        XCTAssertEqual(reserialized, "<ul><li>first</li><li><strong>second</strong></li></ul>")
    }

    func testHyperlinkRoundTripsThroughSanitizedHTML() {
        let mutable = NSMutableAttributedString(string: "Folio")
        mutable.addAttribute(.link, value: URL(string: "https://folio.example")!, range: NSRange(location: 0, length: 5))

        let html = FolioRichTextEditor.htmlFromAttributedText(mutable)
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertEqual(html, "<p><a href=\"https://folio.example\">Folio</a></p>")
        XCTAssertEqual((parsed.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString, "https://folio.example")
    }

    func testParsedContentUsesTitleInputTextColor() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML("<p>Folio</p>")

        XCTAssertEqual(parsed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor(Color.folioInk))
    }

    func testUnsupportedHyperlinksAreNotParsedOrSerialized() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML("<p><a href=\"javascript:alert(1)\">unsafe</a></p>")
        let mutable = NSMutableAttributedString(string: "unsafe")
        mutable.addAttribute(.link, value: URL(string: "file:///private/unsafe")!, range: NSRange(location: 0, length: 6))

        XCTAssertNil(parsed.attribute(.link, at: 0, effectiveRange: nil))
        XCTAssertEqual(FolioRichTextEditor.htmlFromAttributedText(mutable), "<p>unsafe</p>")
    }

    func testFallbackHTMLParserRemovesUnsupportedHyperlinks() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML("<div><a href=\"javascript:alert(1)\">unsafe</a></div>")

        XCTAssertNil(parsed.attribute(.link, at: 0, effectiveRange: nil))
    }

    func testUnicodeAndEmojiRoundTripThroughParagraphHTML() {
        let text = NSAttributedString(string: "Café 📚 — 東京")

        let html = FolioRichTextEditor.htmlFromAttributedText(text)
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertEqual(parsed.string, text.string)
    }

    func testMalformedSupportedHTMLFallsBackWithoutCrashing() {
        let parsed = FolioRichTextEditor.attributedTextFromHTML("<p><strong>Unclosed")

        XCTAssertTrue(parsed.string.contains("Unclosed"))
    }

    func testMixedInlineFormattingAndLinkRoundTrips() {
        let mutable = NSMutableAttributedString(string: "Folio")
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .bold), range: fullRange)
        mutable.addAttribute(.link, value: URL(string: "https://folio.example")!, range: fullRange)

        let html = FolioRichTextEditor.htmlFromAttributedText(mutable)
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)

        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("<a href=\"https://folio.example\">"))
        XCTAssertTrue((parsed.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString == "https://folio.example")
        let font = parsed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    func testAttributedTextFromHTMLAppliesParagraphSpacingToParagraphsAndListBoundaries() {
        let html = "<ol><li>One</li><li>Two</li></ol>\n<p>Paragraph 1</p>\n<p>Paragraph 2</p>"
        let parsed = FolioRichTextEditor.attributedTextFromHTML(html)
        let string = parsed.string as NSString

        let item1Range = string.range(of: "One")
        let item2Range = string.range(of: "Two")
        let p1Range = string.range(of: "Paragraph 1")
        let p2Range = string.range(of: "Paragraph 2")

        let style1 = parsed.attribute(.paragraphStyle, at: item1Range.location, effectiveRange: nil) as? NSParagraphStyle
        let style2 = parsed.attribute(.paragraphStyle, at: item2Range.location, effectiveRange: nil) as? NSParagraphStyle
        let styleP1 = parsed.attribute(.paragraphStyle, at: p1Range.location, effectiveRange: nil) as? NSParagraphStyle
        let styleP2 = parsed.attribute(.paragraphStyle, at: p2Range.location, effectiveRange: nil) as? NSParagraphStyle

        XCTAssertEqual(style1?.paragraphSpacing, 0)
        XCTAssertEqual(style2?.paragraphSpacing, FolioRichTextFormat.paragraphSpacing)
        XCTAssertEqual(styleP1?.paragraphSpacing, FolioRichTextFormat.paragraphSpacing)
        XCTAssertEqual(styleP2?.paragraphSpacing, FolioRichTextFormat.paragraphSpacing)
    }

    // MARK: shouldAllowTextEdit

    func testCaretInsertInsideMarkerIsRejected() {
        // "•\tmilk" — marker at (0, 2). Caret between "•"(0) and tab(1).
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertFalse(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 1, length: 0), markers: markers))
    }

    func testCaretInsertAtMarkerStartIsRejected() {
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertFalse(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 0, length: 0), markers: markers))
    }

    func testCaretInsertAfterMarkerIsAllowed() {
        // Caret at position 2 (after the tab) — not inside the marker.
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertTrue(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 2, length: 0), markers: markers))
    }

    func testSelectAllDeleteIsAllowed() {
        // Whole document selection covers the marker fully.
        let markers = [NSRange(location: 0, length: 2)]
        XCTAssertTrue(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 0, length: 10), markers: markers))
    }

    func testSelectionCoveringWholeMarkerIsAllowed() {
        let markers = [NSRange(location: 5, length: 2)]
        XCTAssertTrue(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 4, length: 4), markers: markers))
    }

    func testSelectionPartiallyOverlappingMarkerIsRejected() {
        let markers = [NSRange(location: 5, length: 2)]
        // Selects only the "•" (first char of the marker), leaving the tab behind.
        XCTAssertFalse(FolioRichTextEditor.shouldAllowTextEdit(in: NSRange(location: 5, length: 1), markers: markers))
    }

    private func makeLaidOutTextView(width: CGFloat, text: NSAttributedString) -> FolioTextView {
        let textView = FolioTextView(frame: CGRect(x: 0, y: 0, width: width, height: 400))
        textView.font = UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.attributedText = text
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        return textView
    }

    private func quotedAttributedText(_ value: String) -> NSAttributedString {
        let paragraphs = value.split(separator: "\n", omittingEmptySubsequences: false)
        let attributed = NSMutableAttributedString(string: paragraphs.map { "> " + $0 }.joined(separator: "\n"))
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.blockquoteIndent
        style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        attributed.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attributed.length))
        attributed.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize),
            range: NSRange(location: 0, length: attributed.length)
        )
        return attributed
    }

    private func quotedThenPlainThenQuotedText() -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: "> first\nplain\n> second")
        let style = NSMutableParagraphStyle()
        style.headIndent = FolioRichTextFormat.blockquoteIndent
        style.firstLineHeadIndent = FolioRichTextFormat.blockquoteIndent
        attributed.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: 7))
        attributed.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 14, length: 8))
        attributed.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: FolioRichTextFormat.bodyFontSize),
            range: NSRange(location: 0, length: attributed.length)
        )
        return attributed
    }
}
