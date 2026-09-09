@testable import Folio
import XCTest

final class SheetHeightMeasurementTests: XCTestCase {
    func testHeightOnlyNeedsUpdateWhenDifferenceExceedsTolerance() {
        XCTAssertFalse(SheetHeightMeasurement.needsUpdate(current: 200, measured: 200.25))
        XCTAssertTrue(SheetHeightMeasurement.needsUpdate(current: 200, measured: 201))
    }
}
