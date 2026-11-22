import AppKit
import Foundation
import Observation

struct ReleaseInfo: Equatable, Sendable {
    let version: String
    let tagName: String
    let releaseNotes: String
    let releaseURL: URL
    let downloadURL: URL?
}

@MainActor
@Observable
final class UpdateChecker {
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/yeoleobun/Lollipop/releases/latest")!
    private static let lastCheckKey = "LollipopLastUpdateCheckTimestamp"
    private static let autoCheckInterval: TimeInterval = 6 * 3600

    static let brewUpgradeCommand = "brew upgrade --cask lollipop"

    private(set) var isChecking = false
    private(set) var availableUpdate: ReleaseInfo? = nil
    var showUpdateSheet = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func checkOnLaunchIfNeeded() {
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        let now = Date().timeIntervalSince1970
        if now - last < Self.autoCheckInterval {
            return
        }
        Task {
            // Delay slightly so startup stays instant
            try? await Task.sleep(for: .seconds(4))
            await performCheck(userInitiated: false)
        }
    }

    func checkForUpdatesManually() {
        Task {
            await performCheck(userInitiated: true)
        }
    }

    private func performCheck(userInitiated: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)

            if Self.isVersion(release.version, newerThan: currentVersion) {
                availableUpdate = release
                if userInitiated {
                    showUpdateSheet = true
                }
            } else {
                availableUpdate = nil
                if userInitiated {
                    showUpToDateAlert()
                }
            }
        } catch {
            if userInitiated {
                showCheckFailedAlert(message: error.localizedDescription)
            }
        }
    }

    private func fetchLatestRelease() async throws -> ReleaseInfo {
        struct GitHubAsset: Decodable {
            let name: String
            let browser_download_url: String
        }
        struct GitHubReleasePayload: Decodable {
            let tag_name: String
            let body: String?
            let html_url: String
            let assets: [GitHubAsset]?
        }

        var request = URLRequest(url: Self.latestReleaseAPI)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Lollipop/\(currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(
                domain: "LollipopUpdater",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "GitHub API returned HTTP \(http.statusCode)."]
            )
        }

        let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
        let normalizedVersion = Self.normalizeVersion(payload.tag_name)
        let releaseURL = URL(string: payload.html_url)
            ?? URL(string: "https://github.com/yeoleobun/Lollipop/releases/latest")!
        let dmgAsset = payload.assets?.first(where: { $0.name.hasSuffix(".dmg") })
            ?? payload.assets?.first(where: { $0.name.hasSuffix(".zip") })
        let downloadURL = dmgAsset.flatMap { URL(string: $0.browser_download_url) }

        return ReleaseInfo(
            version: normalizedVersion,
            tagName: payload.tag_name,
            releaseNotes: (payload.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            releaseURL: releaseURL,
            downloadURL: downloadURL
        )
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.upToDateTitle
        alert.informativeText = L10n.upToDateMessage(currentVersion)
        alert.addButton(withTitle: L10n.ok)
        alert.runModal()
    }

    private func showCheckFailedAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.updateCheckFailedTitle
        alert.informativeText = message
        alert.addButton(withTitle: L10n.ok)
        alert.runModal()
    }

    // MARK: - Semver Comparison

    nonisolated static func normalizeVersion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = normalizeVersion(candidate).split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        let b = normalizeVersion(current).split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        let count = max(a.count, b.count)
        for i in 0..<count {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}
