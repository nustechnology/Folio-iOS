import SwiftUI
import UIKit

struct FolioShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootView = scene.keyWindow?.rootViewController?.view {
            controller.popoverPresentationController?.sourceView = rootView
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: rootView.bounds.midX,
                y: rootView.bounds.midY,
                width: 1,
                height: 1
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
