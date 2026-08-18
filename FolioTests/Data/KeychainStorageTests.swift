@testable import Folio
import Foundation
import XCTest

final class KeychainStorageTests: XCTestCase {
    func testAppStartupRemovesLegacyAuthenticationSession() {
        UserDefaults.standard.set(Data(), forKey: StorageKey.authSession)

        _ = FolioApp()

        XCTAssertNil(UserDefaults.standard.object(forKey: StorageKey.authSession))
    }
}

final class SystemKeychainClientTests: XCTestCase {
    private let data = "token".data(using: .utf8)!

    func testLoadReturnsNilWhenItemNotFound() throws {
        let secItem = MockSecItemClient()
        secItem.copyStatus = errSecItemNotFound
        let client = SystemKeychainClient(secItem: secItem)

        XCTAssertNil(try client.loadData(service: "svc", account: "acct"))
    }

    func testLoadReturnsDataOnSuccess() throws {
        let secItem = MockSecItemClient()
        secItem.copyData = data
        let client = SystemKeychainClient(secItem: secItem)

        XCTAssertEqual(try client.loadData(service: "svc", account: "acct"), data)
    }

    func testLoadThrowsOnFailure() {
        let secItem = MockSecItemClient()
        secItem.copyStatus = errSecAuthFailed
        let client = SystemKeychainClient(secItem: secItem)

        XCTAssertThrowsError(try client.loadData(service: "svc", account: "acct"))
    }

    func testSaveUpdatesExistingItem() throws {
        let secItem = MockSecItemClient()
        secItem.updateStatus = errSecSuccess
        let client = SystemKeychainClient(secItem: secItem)

        try client.saveData(data, service: "svc", account: "acct")

        XCTAssertEqual(secItem.updateCallCount, 1)
        XCTAssertEqual(secItem.insertCallCount, 0)
    }

    func testSaveInsertsWhenUpdateReportsItemNotFound() throws {
        let secItem = MockSecItemClient()
        secItem.updateStatus = errSecItemNotFound
        secItem.insertStatus = errSecSuccess
        let client = SystemKeychainClient(secItem: secItem)

        try client.saveData(data, service: "svc", account: "acct")

        XCTAssertEqual(secItem.updateCallCount, 1)
        XCTAssertEqual(secItem.insertCallCount, 1)
    }

    func testSaveThrowsWhenUpdateFails() {
        let secItem = MockSecItemClient()
        secItem.updateStatus = errSecAuthFailed
        let client = SystemKeychainClient(secItem: secItem)

        XCTAssertThrowsError(try client.saveData(data, service: "svc", account: "acct"))
        XCTAssertEqual(secItem.insertCallCount, 0)
    }

    func testSaveThrowsWhenInsertFails() {
        let secItem = MockSecItemClient()
        secItem.updateStatus = errSecItemNotFound
        secItem.insertStatus = errSecAuthFailed
        let client = SystemKeychainClient(secItem: secItem)

        XCTAssertThrowsError(try client.saveData(data, service: "svc", account: "acct"))
        XCTAssertEqual(secItem.insertCallCount, 1)
    }

    func testRemoveSucceedsWhenItemNotFound() throws {
        let secItem = MockSecItemClient()
        secItem.deleteStatus = errSecItemNotFound
        let client = SystemKeychainClient(secItem: secItem)

        try client.removeData(service: "svc", account: "acct")
    }

    func testRemoveThrowsOnFailure() {
        let secItem = MockSecItemClient()
        secItem.deleteStatus = errSecAuthFailed
        let client = SystemKeychainClient(secItem: secItem)

        XCTAssertThrowsError(try client.removeData(service: "svc", account: "acct"))
    }
}

private final class MockSecItemClient: SecItemClient {
    var copyStatus: OSStatus = errSecSuccess
    var copyData: Data?
    var updateStatus: OSStatus = errSecSuccess
    var insertStatus: OSStatus = errSecSuccess
    var deleteStatus: OSStatus = errSecSuccess
    private(set) var updateCallCount = 0
    private(set) var insertCallCount = 0

    func copyMatching(_ query: [CFString: Any]) -> (status: OSStatus, data: Data?) {
        (copyStatus, copyData)
    }

    func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus {
        updateCallCount += 1
        return updateStatus
    }

    func add(_ attributes: [CFString: Any]) -> OSStatus {
        insertCallCount += 1
        return insertStatus
    }

    func delete(_ query: [CFString: Any]) -> OSStatus {
        deleteStatus
    }
}
