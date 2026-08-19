@testable import Folio
import XCTest

final class AppConfigurationTests: XCTestCase {
    func testValidatedBaseURLAcceptsHTTPSURLWithHost() {
        let url = AppConfiguration.validatedBaseURL("https://api.example.com/v1")

        XCTAssertEqual(url?.host, "api.example.com")
        XCTAssertEqual(url?.path, "/v1")
    }

    func testValidatedBaseURLRejectsNonHTTPSURL() {
        XCTAssertNil(AppConfiguration.validatedBaseURL("http://api.example.com"))
    }

    func testValidatedBaseURLRejectsURLWithoutHost() {
        XCTAssertNil(AppConfiguration.validatedBaseURL("https:///missing-host"))
    }
}
