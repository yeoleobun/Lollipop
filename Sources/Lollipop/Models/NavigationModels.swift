import Foundation

// MARK: - Sidebar & Tabs

enum SidebarDestination: Hashable, Identifiable {
    case home
    case explore
    case charts
    case search
    case likedSongs
    case history
    case library
    case playlist(id: String, title: String)

    var id: String {
        switch self {
        case .home: return "home"
        case .explore: return "explore"
        case .charts: return "charts"
        case .search: return "search"
        case .likedSongs: return "likedSongs"
        case .history: return "history"
        case .library: return "library"
        case .playlist(let id, _): return "playlist:\(id)"
        }
    }

    var title: String {
        switch self {
        case .home: return L10n.home
        case .explore: return L10n.explore
        case .charts: return L10n.charts
        case .search: return L10n.search
        case .likedSongs: return L10n.likedSongs
        case .history: return L10n.history
        case .library: return L10n.library
        case .playlist(_, let title): return title
        }
    }

    var systemImage: String {
        switch self {
        case .home: return AppSymbols.home
        case .explore: return AppSymbols.explore
        case .charts: return AppSymbols.charts
        case .search: return AppSymbols.search
        case .likedSongs: return AppSymbols.likedSongs
        case .history: return AppSymbols.history
        case .library: return AppSymbols.library
        case .playlist: return AppSymbols.playlist
        }
    }
}

enum LibraryTab: String, CaseIterable, Identifiable {
    case songs
    case albums
    case artists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songs: return L10n.songs
        case .albums: return L10n.albums
        case .artists: return L10n.artists
        }
    }

    var browseId: String {
        switch self {
        case .songs: return YouTubeMusicConstants.BrowseID.likedVideos
        case .albums: return YouTubeMusicConstants.BrowseID.likedAlbums
        case .artists: return YouTubeMusicConstants.BrowseID.libraryArtists
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case queue
    case lyrics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .queue: return L10n.playingNext
        case .lyrics: return L10n.lyrics
        }
    }

    var systemImage: String {
        switch self {
        case .queue: return AppSymbols.queueList
        case .lyrics: return AppSymbols.lyricsQuote
        }
    }
}

enum SearchFilter: String, CaseIterable, Identifiable {
    case all
    case songs
    case albums
    case playlists
    case artists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.topResults
        case .songs: return L10n.songs
        case .albums: return L10n.albums
        case .playlists: return L10n.playlists
        case .artists: return L10n.artists
        }
    }

    var innertubeParams: String? {
        switch self {
        case .all: return nil
        case .songs: return YouTubeMusicConstants.SearchParams.songs
        case .albums: return YouTubeMusicConstants.SearchParams.albums
        case .playlists: return YouTubeMusicConstants.SearchParams.playlists
        case .artists: return YouTubeMusicConstants.SearchParams.artists
        }
    }
}

// MARK: - Playlist Editor Models

enum PlaylistPrivacyOption: String, CaseIterable, Identifiable {
    case `private` = "PRIVATE"
    case unlisted = "UNLISTED"
    case `public` = "PUBLIC"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .private: return L10n.privacyPrivate
        case .unlisted: return L10n.privacyUnlisted
        case .public: return L10n.privacyPublic
        }
    }
}

enum PlaylistEditorMode: Identifiable {
    case create(initialVideoId: String? = nil)
    case edit(playlistId: String, title: String, description: String)

    var id: String {
        switch self {
        case .create(let vid): return "create-\(vid ?? "empty")"
        case .edit(let pid, _, _): return "edit-\(pid)"
        }
    }
}

// MARK: - Routing

struct NavigationRoute: Hashable {
    let browseId: String
    let title: String
    let artworkURL: String
    var autoPlay: Bool = false
    var autoPlayVideoId: String? = nil
}

struct BrowseRoute: Hashable {
    let browseId: String
    let params: String?
    let title: String
}

enum AppRoute: Hashable {
    case collection(NavigationRoute)
    case section(MusicSection)
    case browse(BrowseRoute)
}

// MARK: - Shared Item Navigation Helper

@MainActor
enum MusicItemNavigator {
    static func handleCardTap(
        _ item: MusicItem,
        engine: YouTubeMusicEngine,
        onOpenRoute: (NavigationRoute) -> Void
    ) {
        if item.kind == .artist, let browseId = item.browseId {
            onOpenRoute(
                NavigationRoute(browseId: browseId, title: item.title, artworkURL: item.artworkURL)
            )
            return
        }

        // Song card: open its album when available without auto-playing;
        // the card's play button handles direct playback.
        if item.videoId != nil {
            let fallbackAlbumBrowseId = item.browseId.flatMap {
                YouTubeMusicConstants.isAlbumBrowseId($0) ? $0 : nil
            }
            if let albumId = item.albumBrowseId ?? fallbackAlbumBrowseId {
                onOpenRoute(
                    NavigationRoute(
                        browseId: albumId,
                        title: item.albumTitle ?? item.title,
                        artworkURL: item.artworkURL
                    )
                )
            } else {
                engine.play(item: item)
            }
            return
        }

        if let targetBrowseId = item.albumBrowseId ?? item.browseId ?? item.playlistId {
            onOpenRoute(
                NavigationRoute(
                    browseId: targetBrowseId,
                    title: item.albumTitle ?? item.title,
                    artworkURL: item.artworkURL
                )
            )
        }
    }

    static func handleRowTap(
        _ item: MusicItem,
        engine: YouTubeMusicEngine,
        onOpenRoute: (NavigationRoute) -> Void
    ) {
        if item.kind == .song, item.videoId != nil {
            engine.play(item: item)
        } else if let browseId = item.browseId {
            onOpenRoute(
                NavigationRoute(browseId: browseId, title: item.title, artworkURL: item.artworkURL)
            )
        } else {
            engine.play(item: item)
        }
    }
}
