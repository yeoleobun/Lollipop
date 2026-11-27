import Foundation

// MARK: - Playback State

enum RepeatMode: String, Codable, Sendable {
    case off
    case all
    case one

    var systemImage: String {
        switch self {
        case .off, .all: return AppSymbols.repeatAll
        case .one: return AppSymbols.repeatOne
        }
    }
}

enum LikeStatus: String, Codable, Sendable {
    case indifferent
    case like
    case dislike
}

struct PlayerState: Equatable, Sendable {
    var videoId: String = ""
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artworkURL: String = ""
    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var volume: Double = 100
    var isMuted: Bool = false
    var repeatMode: RepeatMode = .off
    var isShuffled: Bool = false
    var likeStatus: LikeStatus = .indifferent
    var isSignedIn: Bool = false
    var accountName: String = ""
    var accountEmail: String = ""
    var accountAvatarURL: String = ""
    var artistBrowseId: String = ""
    var albumBrowseId: String = ""
    var isReady: Bool = false

    var hasTrack: Bool {
        !title.isEmpty || !videoId.isEmpty
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
}

// MARK: - Music Content Models

enum MediaItemKind: String, Codable, Sendable, Hashable {
    case song
    case album
    case playlist
    case artist
    case category
    case unknown
}

struct MusicItem: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var artworkURL: String
    var kind: MediaItemKind
    var videoId: String?
    var browseId: String?
    var browseParams: String? = nil
    var playlistId: String?
    var durationText: String?
    var artistName: String?
    var albumTitle: String?
    var artistBrowseId: String?
    var albumBrowseId: String?
    var setVideoId: String? = nil
    var accentColorHex: String? = nil
    var iconType: String? = nil
    var isExplicit: Bool = false

    var resolvedArtworkURL: URL? {
        guard !artworkURL.isEmpty else { return nil }
        return URL(string: artworkURL)
    }
}

enum SectionLayout: String, Codable, Sendable {
    case carousel
    case quickPicks
    case list
    case moodGrid
    case categoryGrid
}

struct MusicSection: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var subtitle: String?
    var layout: SectionLayout
    var moreBrowseId: String? = nil
    var moreBrowseParams: String? = nil
    var moreButtonTitle: String? = nil
    var playAllVideoId: String? = nil
    var playAllPlaylistId: String? = nil
    var playAllParams: String? = nil
    var items: [MusicItem]
}

struct BrowseChip: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var browseId: String
    var params: String?
    var isSelected: Bool
    var deselectBrowseId: String?
    var deselectParams: String?
}

struct BrowsePagePayload: Decodable, Sendable {
    var chips: [BrowseChip]
    var sections: [MusicSection]
    var continuation: String?
}

struct BrowseContinuationPayload: Decodable, Sendable {
    var sections: [MusicSection]
    var continuation: String?
}

struct CollectionDetail: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var description: String
    var artworkURL: String
    var playlistId: String?
    var artistName: String?
    var artistBrowseId: String?
    var isEditable: Bool? = nil
    var tracks: [MusicItem]

    var resolvedArtworkURL: URL? {
        guard !artworkURL.isEmpty else { return nil }
        return URL(string: artworkURL)
    }
}

struct ArtistDetail: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var name: String
    var subscribers: String
    var description: String
    var artworkURL: String
    var shuffleVideoId: String? = nil
    var shufflePlaylistId: String? = nil
    var shuffleParams: String? = nil
    var radioVideoId: String? = nil
    var radioPlaylistId: String? = nil
    var radioParams: String? = nil
    var sections: [MusicSection]
}

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let startTime: Double?
}

struct LyricsData: Equatable, Sendable {
    var lines: [LyricLine]
    var source: String

    var isSynced: Bool {
        lines.contains { $0.startTime != nil }
    }
}

struct UserPlaylist: Identifiable, Hashable, Codable, Sendable {
    var id: String // browseId e.g. VLPL... or VLSE
    var title: String
    var subtitle: String
    var artworkURL: String
    var isAutoPlaylist: Bool? = nil

    var isAuto: Bool {
        isAutoPlaylist == true || id == YouTubeMusicConstants.BrowseID.episodesForLaterPlaylist
    }
}

// MARK: - Formatting Helpers

enum TimeFormatter {
    static func string(from seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return AppConstants.zeroDurationString }
        let total = Int(seconds.rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
