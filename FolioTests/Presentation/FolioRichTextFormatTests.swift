import XCTest
@testable import Folio

final class FolioRichTextFormatTests: XCTestCase {
    func testHeadingFontWeightsAreDistinctFromInlineBold() {
        XCTAssertEqual(FolioRichTextFormat.heading1FontWeight.rawValue, UIFont.Weight.semibold.rawValue)
        XCTAssertEqual(FolioRichTextFormat.heading2FontWeight.rawValue, UIFont.Weight.medium.rawValue)
        XCTAssertEqual(FolioRichTextFormat.heading3FontWeight.rawValue, UIFont.Weight.regular.rawValue)
        XCTAssertEqual(FolioRichTextFormat.inlineBoldFontWeight.rawValue, UIFont.Weight.bold.rawValue)
    }

    func testSingleDigitOrderedMarkerReturnsMarkerEnd() {
        XCTAssertEqual(FolioRichTextFormat.orderedListMarkerLength(in: "1.\tItem"), 3)
    }

    func testMultiDigitOrderedMarkerReturnsMarkerEnd() {
        XCTAssertEqual(FolioRichTextFormat.orderedListMarkerLength(in: "42.\tItem"), 4)
    }

    func testMissingTabAfterDotReturnsNil() {
        XCTAssertNil(FolioRichTextFormat.orderedListMarkerLength(in: "1. Item"))
    }

    func testEmptyInputReturnsNil() {
        XCTAssertNil(FolioRichTextFormat.orderedListMarkerLength(in: ""))
    }

    func testIncompleteMarkerReturnsNil() {
        XCTAssertNil(FolioRichTextFormat.orderedListMarkerLength(in: "1."))
        XCTAssertNil(FolioRichTextFormat.orderedListMarkerLength(in: "1"))
    }

    func testNonNumericPrefixReturnsNil() {
        XCTAssertNil(FolioRichTextFormat.orderedListMarkerLength(in: "a.\tItem"))
    }

    func testBulletMarkerReturnsNil() {
        XCTAssertNil(FolioRichTextFormat.orderedListMarkerLength(in: "•\tItem"))
    }
}
