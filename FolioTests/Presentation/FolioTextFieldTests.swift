import XCTest
@testable import Folio

final class FolioTextFieldTests: XCTestCase {
    func testTruncatedTextKeepsTextWithinConfiguredMaximumLength() {
        XCTAssertEqual(FolioTextField.truncatedText("12345", maxLength: 3), "123")
    }

    func testTruncatedTextLeavesTextUnchangedWithoutMaximumLength() {
        XCTAssertEqual(FolioTextField.truncatedText("12345", maxLength: nil), "12345")
    }
}
