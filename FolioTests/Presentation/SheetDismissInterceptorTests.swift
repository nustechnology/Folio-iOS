@testable import Folio
import SwiftUI
import UIKit
import XCTest

final class SheetDismissInterceptorTests: XCTestCase {
    private func makePresentationController() -> UIPresentationController {
        UIPresentationController(
            presentedViewController: UIViewController(),
            presenting: UIViewController()
        )
    }

    func testCoordinatorRefusesDismissalWhenBlocked() {
        let coordinator = SheetDismissInterceptor.Coordinator(
            isBlocked: true,
            onAttemptToDismiss: {}
        )

        XCTAssertFalse(coordinator.presentationControllerShouldDismiss(makePresentationController()))
    }

    func testCoordinatorAllowsDismissalWhenNotBlocked() {
        let coordinator = SheetDismissInterceptor.Coordinator(
            isBlocked: false,
            onAttemptToDismiss: {}
        )

        XCTAssertTrue(coordinator.presentationControllerShouldDismiss(makePresentationController()))
    }

    func testCoordinatorReportsPreventedAttempt() {
        var attempts = 0
        let coordinator = SheetDismissInterceptor.Coordinator(
            isBlocked: true,
            onAttemptToDismiss: { attempts += 1 }
        )

        coordinator.presentationControllerDidAttemptToDismiss(makePresentationController())

        XCTAssertEqual(attempts, 1)
    }

    func testCoordinatorFollowsBlockedChanges() {
        var attempts = 0
        let coordinator = SheetDismissInterceptor.Coordinator(
            isBlocked: true,
            onAttemptToDismiss: { attempts += 1 }
        )

        coordinator.isBlocked = false
        XCTAssertTrue(coordinator.presentationControllerShouldDismiss(makePresentationController()))

        coordinator.isBlocked = true
        XCTAssertFalse(coordinator.presentationControllerShouldDismiss(makePresentationController()))
        coordinator.presentationControllerDidAttemptToDismiss(makePresentationController())
        XCTAssertEqual(attempts, 1)
    }

    @MainActor
    func testInterceptorAttachesToPresentedSheetPresentationController() {
        var attemptFired = false

        let presenter = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = presenter
        window.makeKeyAndVisible()

        let sheetHost = UIHostingController(
            rootView: InterceptorProbeView(
                isBlocked: true,
                onAttemptToDismiss: { attemptFired = true }
            )
        )
        presenter.present(sheetHost, animated: false)

        let presentationController = waitForInterceptorAttachment(on: sheetHost)

        defer {
            sheetHost.dismiss(animated: false)
            window.isHidden = true
        }

        guard let presentationController else {
            return XCTFail("Expected the interceptor to attach to the presented sheet")
        }

        XCTAssertTrue(
            sheetHost.isModalInPresentation,
            "The interceptor should set isModalInPresentation when blocked"
        )
        XCTAssertFalse(
            presentationController.delegate?.presentationControllerShouldDismiss?(presentationController) ?? true,
            "The interceptor should refuse dismissal when blocked"
        )

        presentationController.delegate?.presentationControllerDidAttemptToDismiss?(presentationController)
        XCTAssertTrue(attemptFired, "The interceptor should report a prevented dismissal attempt")
    }

    private func waitForInterceptorAttachment(
        on sheetHost: UIHostingController<InterceptorProbeView>,
        timeout: TimeInterval = 2
    ) -> UIPresentationController? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            if let presentationController = sheetHost.presentationController,
                presentationController.delegate is SheetDismissInterceptor.Coordinator,
                sheetHost.isModalInPresentation {
                return presentationController
            }
        }
        return nil
    }
}

private struct InterceptorProbeView: View {
    let isBlocked: Bool
    let onAttemptToDismiss: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 240, height: 240)
            .interceptInteractiveDismiss(
                isBlocked: isBlocked,
                onAttemptToDismiss: onAttemptToDismiss
            )
    }
}
