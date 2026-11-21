import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force modern floating overlay scrollbars (no legacy gray track frame)
        UserDefaults.standard.set(
            AppConstants.scrollBarsWhenScrolling,
            forKey: AppConstants.scrollBarsDefaultsKey
        )
        NSApp.setActivationPolicy(.regular)
        if let iconPath = Bundle.main.path(
            forResource: AppConstants.appIconName,
            ofType: AppConstants.appIconExtension
        ),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct LollipopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @ViewState private var engine = YouTubeMusicEngine()
    @ViewState private var showInspector = false
    @ViewState private var inspectorTab: InspectorTab = .queue

    var body: some Scene {
        WindowGroup(AppConstants.appName) {
            MainView(
                engine: engine,
                showInspector: $showInspector,
                inspectorTab: $inspectorTab
            )
            .frame(
                minWidth: AppMetrics.mainWindowMinWidth,
                minHeight: AppMetrics.mainWindowMinHeight
            )
        }
        .defaultSize(
            width: AppMetrics.mainWindowDefaultWidth,
            height: AppMetrics.mainWindowDefaultHeight
        )
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppCommands(
                engine: engine,
                showInspector: $showInspector,
                inspectorTab: $inspectorTab
            )
        }
    }
}
