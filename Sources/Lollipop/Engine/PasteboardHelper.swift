import AppKit

/// Clipboard helpers isolated from SwiftUI view definitions.
@MainActor
enum PasteboardHelper {
    static func copyTrackLink(videoId: String) {
        guard !videoId.isEmpty else { return }
        copyString(YouTubeMusicConstants.watchURL(videoId: videoId))
    }

    static func copyString(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
