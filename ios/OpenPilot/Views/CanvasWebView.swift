import SwiftUI
import WebKit

/// Renders a Canvas preview document in a WKWebView. Reloads only when the HTML
/// actually changes, so toggling/editing doesn't flicker. Sandboxed to local
/// content: no navigation to remote URLs is allowed.
struct CanvasWebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String?
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow the initial local load; block remote navigation (links, redirects).
            if navigationAction.navigationType == .other || navigationAction.targetFrame == nil {
                decisionHandler(.allow)
            } else if let url = navigationAction.request.url, url.scheme == "about" || url.scheme == "file" {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.isOpaque = false
        wv.backgroundColor = .white
        wv.scrollView.backgroundColor = .white
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            wv.loadHTMLString(html, baseURL: nil)
        }
    }
}