@testable import Folio
import UIKit
import XCTest

final class KeyboardDismissalTests: XCTestCase {
    func testDismissesForTapOutsideTextInputs() {
        XCTAssertTrue(KeyboardDismissal.shouldDismiss(for: UIView()))
    }

    func testIgnoresTextFieldAndTextViewTaps() {
        XCTAssertFalse(KeyboardDismissal.shouldDismiss(for: UITextField()))
        XCTAssertFalse(KeyboardDismissal.shouldDismiss(for: UITextView()))
    }
}
