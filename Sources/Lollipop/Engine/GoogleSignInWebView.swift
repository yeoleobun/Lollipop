import AppKit
import SwiftUI
@preconcurrency import WebKit

/// Dedicated compact `WKWebView` sharing `WKWebsiteDataStore.default()` with the hidden audio engine.
struct GoogleSignInWebView: NSViewRepresentable {
    let onCompleted: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompleted: onCompleted)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Skip unsupported WebAuthn/Bluetooth Passkey prompt in WKWebView
        let disableWebAuthn = WKUserScript(
            source: BridgeScript.disableWebAuthnSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(disableWebAuthn)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = AppConstants.safariUserAgent
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        if let url = URL(string: AppConstants.googleSignInURL) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onCompleted: @MainActor () -> Void
        private var didComplete = false

        init(onCompleted: @escaping @MainActor () -> Void) {
            self.onCompleted = onCompleted
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCompletion(url: webView.url)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url, isYouTubeMusicLanding(url) {
                decisionHandler(.cancel)
                finishOnce()
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func checkCompletion(url: URL?) {
            guard let url, isYouTubeMusicLanding(url) else { return }
            finishOnce()
        }

        private func isYouTubeMusicLanding(_ url: URL) -> Bool {
            url.host?.lowercased() == YouTubeMusicConstants.host
        }

        private func finishOnce() {
            guard !didComplete else { return }
            didComplete = true
            onCompleted()
        }
    }
}
