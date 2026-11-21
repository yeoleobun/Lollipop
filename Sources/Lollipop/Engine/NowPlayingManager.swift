import Foundation
import MediaPlayer

/// Coordinates macOS Now Playing without duplicating WebKit's built-in MediaSession.
/// WebKit's WebContent process already publishes the active HTML5 audio stream to
/// macOS Control Center and hardware media keys (with `BridgeScript` normalizing
/// `navigator.mediaSession` to use Next/Previous track instead of 15s skip buttons).
/// Writing a second `MPNowPlayingInfoCenter` entry from the host process would cause
/// duplicate Now Playing cards in Control Center.
@MainActor
final class NowPlayingManager {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onSeek: ((Double) -> Void)?

    init() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .unknown
    }

    func update(with state: PlayerState) {
        // Intentionally delegated to WebKit's single MediaSession publisher
        // to avoid duplicate Now Playing cards in macOS Control Center.
    }
}
