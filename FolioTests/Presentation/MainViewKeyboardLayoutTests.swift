@testable import Folio
import XCTest

final class MainViewKeyboardLayoutTests: XCTestCase {
    func testNotebookChromeIsHiddenWhileKeyboardIsVisible() {
        XCTAssertFalse(MainView.shouldShowNotebookChrome(selectedTab: .notebook, isKeyboardVisible: true))
        XCTAssertTrue(MainView.shouldShowNotebookChrome(selectedTab: .notebook, isKeyboardVisible: false))
    }

    func testKeyboardSafeAreaIsIgnoredOnlyWhenBottomTabBarIsVisible() {
        XCTAssertTrue(MainView.shouldIgnoreKeyboardSafeArea(showTabBar: true, selectedTab: .sources, isKeyboardVisible: false))
        XCTAssertFalse(MainView.shouldIgnoreKeyboardSafeArea(showTabBar: true, selectedTab: .notebook, isKeyboardVisible: false))
        XCTAssertFalse(MainView.shouldIgnoreKeyboardSafeArea(showTabBar: false, selectedTab: .sources, isKeyboardVisible: false))
    }

    func testAskTabKeepsKeyboardSafeAreaWhenKeyboardIsVisible() {
        XCTAssertFalse(MainView.shouldIgnoreKeyboardSafeArea(showTabBar: true, selectedTab: .ask, isKeyboardVisible: true))
    }

    func testBottomTabBarIsHiddenWhileKeyboardIsVisible() {
        XCTAssertFalse(MainView.shouldShowBottomTabBar(showTabBar: true, isKeyboardVisible: true))
        XCTAssertTrue(MainView.shouldShowBottomTabBar(showTabBar: true, isKeyboardVisible: false))
    }
}
