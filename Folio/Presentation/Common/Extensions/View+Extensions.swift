import SwiftUI
import UIKit

extension View {
    func errorAlert(error: Binding<Error?>, onDismiss: (() -> Void)? = nil) -> some View {
        alert(
            "Error",
            isPresented: .constant(error.wrappedValue != nil),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK") {
                error.wrappedValue = nil
                onDismiss?()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    func dismissKeyboardOnTapOutside() -> some View {
        background(alignment: .center) {
            KeyboardDismissalRepresentable()
        }
    }
}

enum KeyboardDismissal {
    static func shouldDismiss(for view: UIView) -> Bool {
        var currentView: UIView? = view
        while let view = currentView {
            if view is UITextField || view is UITextView {
                return false
            }
            currentView = view.superview
        }
        return true
    }

    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct KeyboardDismissalRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissalHostView {
        KeyboardDismissalHostView()
    }

    func updateUIView(_ uiView: KeyboardDismissalHostView, context: Context) {}
}

private final class KeyboardDismissalHostView: UIView {
    private weak var observedWindow: UIWindow?
    private weak var tapRecognizer: UITapGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        removeRecognizer()

        guard let window else { return }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)
        observedWindow = window
        tapRecognizer = recognizer
    }

    deinit {
        removeRecognizer()
    }

    @objc private func handleTap() {
        KeyboardDismissal.dismiss()
    }

    private func removeRecognizer() {
        if let tapRecognizer {
            observedWindow?.removeGestureRecognizer(tapRecognizer)
        }
        tapRecognizer = nil
        observedWindow = nil
    }
}

extension KeyboardDismissalHostView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else { return true }
        return KeyboardDismissal.shouldDismiss(for: view)
    }
}
