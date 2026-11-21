import Foundation

/// YouTube Music / Innertube identifiers, URL builders, classification helpers,
/// and JS bridge method/key constants.
enum YouTubeMusicConstants {
    static let origin = "https://music.youtube.com"
    static let host = "music.youtube.com"
    static let redundantLibrarySectionTitle = "Library"
    static let defaultPrivacyStatus = "PRIVATE"

    static func watchURL(videoId: String) -> String {
        "\(origin)/watch?v=\(videoId)"
    }

    // MARK: - Innertube Browse IDs

    enum BrowseID {
        static let home = "FEmusic_home"
        static let explore = "FEmusic_explore"
        static let charts = "FEmusic_charts"
        static let history = "FEmusic_history"
        static let likedVideos = "FEmusic_liked_videos"
        static let likedAlbums = "FEmusic_liked_albums"
        static let libraryArtists = "FEmusic_library_corpus_track_artists"
        static let likedMusicPlaylist = "VLLM"
        static let likedMusicShortId = "LM"
    }

    // MARK: - ID Prefixes

    enum Prefix {
        static let artist = "UC"
        static let album = "MPREb_"
        static let playlistVL = "VL"
        static let musicFeed = "FEmusic_"
        static let albumPlaylist = "OLAK"
        static let userPlaylist = "PL"
        static let radioPlaylist = "RDCLAK"
    }

    // MARK: - Search Params

    enum SearchParams {
        static let songs = "EgWKAQIIAWoKEAMQBBAJEAoQBQ%3D%3D"
        static let albums = "EgWKAQIYAWoKEAMQBBAJEAoQBQ%3D%3D"
        static let playlists = "EgeKAQQoAEABagoQAxAEEAkQChAF"
        static let artists = "EgWKAQIgAWoKEAMQBBAJEAoQBQ%3D%3D"
    }

    // MARK: - Placeholder Artwork Markers

    private static let placeholderArtworkMarkers = [
        "no_thumbnail",
        "empty_playlist",
        "default_playlist"
    ]

    // MARK: - Classification & Normalization Helpers

    static func isArtistBrowseId(_ id: String) -> Bool {
        id.hasPrefix(Prefix.artist)
    }

    static func isAlbumBrowseId(_ id: String) -> Bool {
        id.hasPrefix(Prefix.album)
    }

    static func isEditablePlaylistBrowseId(_ normalizedId: String) -> Bool {
        normalizedId.hasPrefix(Prefix.playlistVL) && normalizedId != BrowseID.likedMusicPlaylist
    }

    /// Ensures playlist IDs (`OLAK5uy_`, `PL`, `RDCLAK`, `LM`) have the `VL` prefix required by Innertube `browse`.
    static func normalizeCollectionBrowseId(_ rawId: String) -> String {
        let trimmed = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(Prefix.album)
            || trimmed.hasPrefix(Prefix.playlistVL)
            || trimmed.hasPrefix(Prefix.musicFeed)
            || trimmed.hasPrefix(Prefix.artist) {
            return trimmed
        }
        if trimmed.hasPrefix(Prefix.albumPlaylist)
            || trimmed.hasPrefix(Prefix.userPlaylist)
            || trimmed.hasPrefix(Prefix.radioPlaylist)
            || trimmed == BrowseID.likedMusicShortId {
            return Prefix.playlistVL + trimmed
        }
        return trimmed
    }

    static func isPlaceholderArtwork(_ urlString: String) -> Bool {
        urlString.isEmpty || placeholderArtworkMarkers.contains { urlString.contains($0) }
    }

    // MARK: - JavaScript Bridge Protocol

    enum Bridge {
        static let handlerName = "lollipop"
        static let errorDomain = "LollipopEngine"

        static let keyType = "type"
        static let keyPayload = "payload"
        static let eventPlayerState = "playerState"
        static let eventEngineReady = "engineReady"

        enum PayloadKey {
            static let videoId = "videoId"
            static let title = "title"
            static let artist = "artist"
            static let album = "album"
            static let artworkURL = "artworkURL"
            static let isPlaying = "isPlaying"
            static let currentTime = "currentTime"
            static let duration = "duration"
            static let volume = "volume"
            static let isMuted = "isMuted"
            static let isShuffled = "isShuffled"
            static let isSignedIn = "isSignedIn"
            static let isReady = "isReady"
            static let artistBrowseId = "artistBrowseId"
            static let albumBrowseId = "albumBrowseId"
            static let repeatMode = "repeatMode"
            static let likeStatus = "likeStatus"
        }

        // MARK: - Playback JS Calls

        static let togglePlay = "window.__lollipop?.togglePlay()"
        static let play = "window.__lollipop?.play()"
        static let pause = "window.__lollipop?.pause()"
        static let next = "window.__lollipop?.next()"
        static let previous = "window.__lollipop?.previous()"
        static let toggleMute = "window.__lollipop?.toggleMute()"
        static let toggleLike = "window.__lollipop?.toggleLike()"
        static let toggleShuffle = "window.__lollipop?.toggleShuffle()"
        static let cycleRepeat = "window.__lollipop?.cycleRepeat()"

        static func seek(_ seconds: Double) -> String {
            "window.__lollipop?.seek(\(seconds))"
        }

        static func setVolume(_ volume: Double) -> String {
            "window.__lollipop?.setVolume(\(volume))"
        }

        static func playVideo(videoIdJSON: String, playlistIdJSON: String) -> String {
            "window.__lollipop?.playVideo(\(videoIdJSON), \(playlistIdJSON))"
        }

        // MARK: - Async Bridge Calls

        static func likeTrack(videoIdJSON: String) -> String {
            "return await window.__lollipop.likeTrack(\(videoIdJSON));"
        }

        static func fetchBrowse(browseIdJSON: String) -> String {
            "return await window.__lollipop.fetchBrowse(\(browseIdJSON));"
        }

        static let fetchAccountProfile = "return await window.__lollipop.fetchAccountProfile();"
        static let fetchUserPlaylists = "return await window.__lollipop.fetchUserPlaylists();"

        static func createPlaylist(
            titleJSON: String,
            descriptionJSON: String,
            privacyJSON: String,
            videoIdsJS: String
        ) -> String {
            "return await window.__lollipop.createPlaylist(\(titleJSON), \(descriptionJSON), \(privacyJSON), \(videoIdsJS));"
        }

        static func editPlaylistMetadata(
            playlistIdJSON: String,
            titleJSON: String,
            descriptionJSON: String,
            privacyJSON: String
        ) -> String {
            "return await window.__lollipop.editPlaylistMetadata(\(playlistIdJSON), \(titleJSON), \(descriptionJSON), \(privacyJSON));"
        }

        static func addTrackToPlaylist(playlistIdJSON: String, videoIdJSON: String) -> String {
            "return await window.__lollipop.addTrackToPlaylist(\(playlistIdJSON), \(videoIdJSON));"
        }

        static func removeTrackFromPlaylist(
            playlistIdJSON: String,
            videoIdJSON: String,
            setVideoIdJSON: String
        ) -> String {
            "return await window.__lollipop.removeTrackFromPlaylist(\(playlistIdJSON), \(videoIdJSON), \(setVideoIdJSON));"
        }

        static func deletePlaylist(playlistIdJSON: String) -> String {
            "return await window.__lollipop.deletePlaylist(\(playlistIdJSON));"
        }

        static func fetchSearch(queryJSON: String, paramsJSON: String) -> String {
            "return await window.__lollipop.fetchSearch(\(queryJSON), \(paramsJSON));"
        }

        static func fetchArtist(browseIdJSON: String) -> String {
            "return await window.__lollipop.fetchArtist(\(browseIdJSON));"
        }

        static func fetchCollection(browseIdJSON: String) -> String {
            "return await window.__lollipop.fetchCollection(\(browseIdJSON));"
        }

        static func fetchQueueAndLyrics(videoIdJSON: String) -> String {
            "return await window.__lollipop.fetchQueueAndLyrics(\(videoIdJSON));"
        }
    }
}
