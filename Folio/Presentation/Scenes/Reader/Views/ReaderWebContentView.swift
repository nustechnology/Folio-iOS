import SwiftUI
import WebKit

struct ReaderWebContentView: UIViewRepresentable {
    let html: String
    var passageID: String?
    var onContentReady: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.configuration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.loadedHTML = html
        context.coordinator.observeContentSize(of: webView)
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedHTML != html || context.coordinator.appliedPassageID != passageID {
            context.coordinator.loadedHTML = html
            context.coordinator.appliedPassageID = passageID
            context.coordinator.didHighlight = false
            uiView.loadHTMLString(html, baseURL: nil)
        }
    }

    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return configuration
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ReaderWebContentView
        var loadedHTML: String?
        var appliedPassageID: String?
        var didHighlight = false
        private var contentSizeObservation: NSKeyValueObservation?

        init(parent: ReaderWebContentView) {
            self.parent = parent
        }

        deinit {
            contentSizeObservation?.invalidate()
        }

        func observeContentSize(of webView: WKWebView) {
            contentSizeObservation = webView.scrollView.observe(
                \.contentSize,
                options: [.initial, .new]
            ) { [weak self] scrollView, _ in
                DispatchQueue.main.async {
                    self?.parent.onHeightChange?(scrollView.contentSize.height)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onHeightChange?(webView.scrollView.contentSize.height)
            guard !didHighlight else { return }
            didHighlight = true
            applyPassageHighlight(to: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onContentReady?()
        }

        private func applyPassageHighlight(to webView: WKWebView) {
            guard let passageID = parent.passageID, !passageID.isEmpty else {
                parent.onContentReady?()
                return
            }
            guard let encoded = try? JSONSerialization.data(withJSONObject: [passageID]),
                  let json = String(data: encoded, encoding: .utf8) else {
                parent.onContentReady?()
                return
            }
            let script = """
            (function() {
              var id = \(json)[0];
              var el = document.querySelector('[data-passage-id="' + CSS.escape(id) + '"]')
                     || document.getElementById('passage-' + CSS.escape(id))
                     || document.getElementById(CSS.escape(id));
              if (!el) return;
              el.scrollIntoView({ block: 'center', behavior: 'smooth' });
              el.classList.add('folio-evidence-highlight');
            })();
            """
            webView.evaluateJavaScript(script) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.parent.onContentReady?()
                }
            }
        }
    }
}
