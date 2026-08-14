import SwiftUI
import UIKit

struct SheetDismissInterceptor: UIViewRepresentable {
    let isBlocked: Bool
    let onAttemptToDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isBlocked: isBlocked, onAttemptToDismiss: onAttemptToDismiss)
    }

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isBlocked = isBlocked
        context.coordinator.onAttemptToDismiss = onAttemptToDismiss
        DispatchQueue.main.async {
            guard let presentationController = uiView.parentViewController?.presentationController else { return }
            presentationController.delegate = context.coordinator
            presentationController.presentedViewController.isModalInPresentation = isBlocked
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isBlocked: Bool
        var onAttemptToDismiss: () -> Void

        init(isBlocked: Bool, onAttemptToDismiss: @escaping () -> Void) {
            self.isBlocked = isBlocked
            self.onAttemptToDismiss = onAttemptToDismiss
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isBlocked
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttemptToDismiss()
        }
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = next
        while parentResponder != nil {
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
}

extension View {
    func interceptInteractiveDismiss(
        isBlocked: Bool,
        onAttemptToDismiss: @escaping () -> Void
    ) -> some View {
        background(
            SheetDismissInterceptor(isBlocked: isBlocked, onAttemptToDismiss: onAttemptToDismiss)
        )
    }
}
