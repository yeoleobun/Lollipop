import AppKit

/// Clipboard helpers isolated from SwiftUI view definitions.
@MainActor
enum PasteboardHelper {
    static func copyTrackLink(videoId: String) {
        guard !videoId.isEmpty else { return }
        let url = YouTubeMusicConstants.watchURL(videoId: videoId)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }
}
