import AppKit
import SwiftUI
import WebKit

/// Hosts a shared `WKWebView` inside an `NSView` container, safely reparenting it
/// whenever it moves between the hidden background audio host and the visible sign-in sheet.
struct SharedWebViewHost: NSViewRepresentable {
    let webView: WKWebView
    let isActiveHost: Bool

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        if isActiveHost {
            attach(webView, to: container)
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isActiveHost {
            if webView.superview !== nsView {
                attach(webView, to: nsView)
            }
        }
    }

    private func attach(_ webView: WKWebView, to container: NSView) {
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}
