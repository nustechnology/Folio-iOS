import XCTest
import SwiftUI
@testable import Folio

final class FolioTextFieldTests: XCTestCase {
    func testTruncatedTextKeepsTextWithinConfiguredMaximumLength() {
        XCTAssertEqual(FolioTextField.truncatedText("12345", maxLength: 3), "123")
    }

    func testTruncatedTextLeavesTextUnchangedWithoutMaximumLength() {
        XCTAssertEqual(FolioTextField.truncatedText("12345", maxLength: nil), "12345")
    }

    func testPlaceholderTextFieldDoesNotControlFocusByDefault() {
        let field = PlaceholderUITextField(
            placeholder: "",
            placeholderColor: .clear,
            font: .systemFont(ofSize: 14),
            textColor: .label,
            keyboardType: .default,
            isSecureTextEntry: false,
            text: .constant("")
        )

        XCTAssertNil(field.isFirstResponder)
    }
}
