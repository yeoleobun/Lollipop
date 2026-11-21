import Foundation

/// Loads the JavaScript bridge modules bundled under `Resources/Bridge/` in deterministic order.
enum BridgeScript {
    private static let bridgeDirectoryName = "Bridge"
    private static let swiftPMBundleName = "Lollipop_Lollipop.bundle"
    private static let fileExtension = "js"

    private static let coreModuleNames = [
        "01-core",
        "02-parsers",
        "03-player",
        "04-api"
    ]

    static let source: String = loadScripts(named: coreModuleNames)
    static let disableWebAuthnSource: String = loadScripts(named: ["disable-webauthn"])

    private static func loadScripts(named names: [String]) -> String {
        guard let directory = resolveBridgeDirectory() else {
            assertionFailure("Could not locate Bridge JavaScript resources directory.")
            return ""
        }

        var chunks: [String] = []
        chunks.reserveCapacity(names.count)

        for name in names {
            let fileURL = directory
                .appendingPathComponent(name)
                .appendingPathExtension(fileExtension)

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                assertionFailure("Missing or empty Bridge script: \(fileURL.path)")
                continue
            }
            chunks.append(content)
        }

        return chunks.joined(separator: "\n\n")
    }

    private static func resolveBridgeDirectory() -> URL? {
        let fm = FileManager.default
        let mainResourceSubbundle = Bundle.main.resourceURL?.appendingPathComponent(swiftPMBundleName, isDirectory: true)
        let executableSiblingBundle = Bundle.main.bundleURL.appendingPathComponent(swiftPMBundleName, isDirectory: true)

        let candidates: [URL?] = [
            // 1. Standalone packaged macOS app: Lollipop.app/Contents/Resources/Bridge
            Bundle.main.resourceURL?.appendingPathComponent(bridgeDirectoryName, isDirectory: true),
            // 2. Embedded SwiftPM macOS bundle inside Contents/Resources
            mainResourceSubbundle.flatMap { Bundle(url: $0)?.resourceURL }?.appendingPathComponent(bridgeDirectoryName, isDirectory: true),
            mainResourceSubbundle?.appendingPathComponent(bridgeDirectoryName, isDirectory: true),
            // 3. `swift run` / `.build/.../Lollipop_Lollipop.bundle/Contents/Resources/Bridge`
            Bundle(url: executableSiblingBundle)?.resourceURL?.appendingPathComponent(bridgeDirectoryName, isDirectory: true),
            executableSiblingBundle.appendingPathComponent(bridgeDirectoryName, isDirectory: true),
            // 4. Local source tree fallback during development/testing
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Engine/
                .deletingLastPathComponent() // Lollipop/
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent(bridgeDirectoryName, isDirectory: true)
        ]

        return candidates.compactMap { $0 }.first { url in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
    }
}
