import CoreGraphics
import Foundation

/// Centralized application-wide constants, storage identifiers, network settings,
/// and formatting tokens.
enum AppConstants {
    // MARK: - App Identity & Defaults
    static let appName = "Lollipop"
    static let appIconName = "AppIcon"
    static let appIconExtension = "icns"
    static let scrollBarsDefaultsKey = "AppleShowScrollBars"
    static let scrollBarsWhenScrolling = "WhenScrolling"

    // MARK: - Playlist Cover Storage
    static let playlistCoversDirectoryName = "Lollipop/PlaylistCovers"
    static let coverFileExtension = "jpg"
    static let coverFilenameSeparator = "__"
    static let coverMaxPixelDimension: CGFloat = 1024
    static let coverJPEGCompression: CGFloat = 0.88

    // MARK: - WebKit & Authentication
    static let safariUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
    static let googleSignInURL =
        "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com"
    static let authCookieDomains = ["youtube.com", "google.com"]

    // MARK: - LRCLIB & Synced Lyrics
    static let lrcLibExactEndpoint = "https://lrclib.net/api/get"
    static let lrcLibSearchEndpoint = "https://lrclib.net/api/search"
    static let lrcLibUserAgent = "Lollipop/1.0 (macOS)"
    static let lrcLibSourceLabel = "Synced Lyrics • LRCLIB"
    static let lrcLibTimeout: TimeInterval = 6
    static let lyricsSyncLeadTime: Double = 0.25

    // MARK: - Timing
    static let searchDebounceMilliseconds = 350
    static let bridgeRetryDelayMilliseconds = 350

    // MARK: - Formatting & Badges
    static let explicitBadgeLabel = "E"
    static let metadataBullet = "·"
    static let ellipsis = "…"
    static let zeroDurationString = "0:00"
}
