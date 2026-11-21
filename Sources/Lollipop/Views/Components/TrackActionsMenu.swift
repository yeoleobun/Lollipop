import SwiftUI

/// Visual styles for the `•••` track action menu button across different surfaces.
enum TrackEllipsisMenuStyle {
    case rowSubtle
    case playerBar(isEnabled: Bool)
    case fullScreenOverlay
}

/// Shared track action menu items used across TrackRowView, SearchView, NowPlayingBar,
/// FullScreenPlayerView, and MediaCardView.
struct TrackActionsMenuContent: View {
    let artistBrowseId: String?
    let artistTitle: String
    let albumBrowseId: String?
    let albumTitle: String
    let artworkURL: String
    let videoId: String?
    let isCurrentPlayerTrack: Bool
    let isLiked: Bool
    let engine: YouTubeMusicEngine?
    var onOpenRoute: ((NavigationRoute) -> Void)? = nil
    var onRemoveFromPlaylist: (() -> Void)? = nil

    init(
        item: MusicItem,
        engine: YouTubeMusicEngine?,
        onOpenRoute: ((NavigationRoute) -> Void)? = nil,
        onRemoveFromPlaylist: (() -> Void)? = nil
    ) {
        self.artistBrowseId = item.artistBrowseId
        self.artistTitle = item.artistName ?? item.subtitle
        self.albumBrowseId = item.albumBrowseId
        self.albumTitle = item.albumTitle ?? item.title
        self.artworkURL = item.artworkURL
        self.videoId = item.videoId
        self.isCurrentPlayerTrack = false
        self.isLiked = false
        self.engine = engine
        self.onOpenRoute = onOpenRoute
        self.onRemoveFromPlaylist = onRemoveFromPlaylist
    }

    init(
        playerState: PlayerState,
        engine: YouTubeMusicEngine,
        onOpenRoute: ((NavigationRoute) -> Void)? = nil
    ) {
        let cachedTrack = engine.cache.track(for: playerState.videoId)
        let resolvedArtistId = !playerState.artistBrowseId.isEmpty
            ? playerState.artistBrowseId
            : (cachedTrack?.artistBrowseId ?? "")
        let resolvedAlbumId = !playerState.albumBrowseId.isEmpty
            ? playerState.albumBrowseId
            : (cachedTrack?.albumBrowseId ?? "")
        let resolvedAlbumTitle = !playerState.album.isEmpty
            ? playerState.album
            : (cachedTrack?.albumTitle ?? playerState.title)

        self.artistBrowseId = resolvedArtistId.isEmpty ? nil : resolvedArtistId
        self.artistTitle = playerState.artist
        self.albumBrowseId = resolvedAlbumId.isEmpty ? nil : resolvedAlbumId
        self.albumTitle = resolvedAlbumTitle.isEmpty ? playerState.title : resolvedAlbumTitle
        self.artworkURL = playerState.artworkURL
        self.videoId = playerState.videoId.isEmpty ? nil : playerState.videoId
        self.isCurrentPlayerTrack = true
        self.isLiked = playerState.likeStatus == .like
        self.engine = engine
        self.onOpenRoute = onOpenRoute
        self.onRemoveFromPlaylist = nil
    }

    var body: some View {
        if let artistId = artistBrowseId, let onOpenRoute {
            Button {
                onOpenRoute(
                    NavigationRoute(browseId: artistId, title: artistTitle, artworkURL: artworkURL)
                )
            } label: {
                Label(L10n.goToArtist, systemImage: AppSymbols.artistMic)
            }
        }

        if let albumId = albumBrowseId, let onOpenRoute {
            Button {
                onOpenRoute(
                    NavigationRoute(browseId: albumId, title: albumTitle, artworkURL: artworkURL)
                )
            } label: {
                Label(L10n.goToAlbum, systemImage: AppSymbols.albumStack)
            }
        }

        if (artistBrowseId != nil || albumBrowseId != nil) && (videoId != nil || isCurrentPlayerTrack) {
            Divider()
        }

        if let vid = videoId, !vid.isEmpty, let engine, engine.isSignedIn {
            Menu {
                Button {
                    engine.presentCreatePlaylist(initialVideoId: vid)
                } label: {
                    Label(L10n.newPlaylistEllipsis, systemImage: AppSymbols.plus)
                }

                if !engine.userPlaylists.isEmpty {
                    Divider()
                    ForEach(engine.userPlaylists) { playlist in
                        Button {
                            Task {
                                _ = await engine.addTrackToPlaylist(playlistId: playlist.id, videoId: vid)
                            }
                        } label: {
                            Label(playlist.title, systemImage: AppSymbols.playlist)
                        }
                    }
                }
            } label: {
                Label(L10n.addToPlaylist, systemImage: AppSymbols.addToPlaylist)
            }
        }

        if isCurrentPlayerTrack, let engine {
            Button {
                engine.toggleLike()
            } label: {
                Label(
                    isLiked ? L10n.unlike : L10n.like,
                    systemImage: isLiked ? AppSymbols.heartSlash : AppSymbols.heart
                )
            }
        } else if let vid = videoId, !vid.isEmpty, let engine, engine.isSignedIn {
            Button {
                Task {
                    _ = await engine.likeTrack(videoId: vid)
                }
            } label: {
                Label(L10n.like, systemImage: AppSymbols.heart)
            }
        }

        if let onRemoveFromPlaylist {
            Divider()
            Button(role: .destructive, action: onRemoveFromPlaylist) {
                Label(L10n.removeFromPlaylist, systemImage: AppSymbols.trash)
            }
        }

        if let vid = videoId, !vid.isEmpty {
            Divider()
            Button {
                PasteboardHelper.copyTrackLink(videoId: vid)
            } label: {
                Label(L10n.copyLink, systemImage: AppSymbols.link)
            }
        }
    }
}

/// Reusable `•••` menu button wrapping `TrackActionsMenuContent` with surface-appropriate styling.
struct TrackEllipsisMenuButton: View {
    let style: TrackEllipsisMenuStyle
    let artistBrowseId: String?
    let artistTitle: String
    let albumBrowseId: String?
    let albumTitle: String
    let artworkURL: String
    let videoId: String?
    let isCurrentPlayerTrack: Bool
    let isLiked: Bool
    let engine: YouTubeMusicEngine?
    var onOpenRoute: ((NavigationRoute) -> Void)? = nil
    var onRemoveFromPlaylist: (() -> Void)? = nil

    init(
        style: TrackEllipsisMenuStyle,
        item: MusicItem,
        engine: YouTubeMusicEngine?,
        onOpenRoute: ((NavigationRoute) -> Void)? = nil,
        onRemoveFromPlaylist: (() -> Void)? = nil
    ) {
        self.style = style
        self.artistBrowseId = item.artistBrowseId
        self.artistTitle = item.artistName ?? item.subtitle
        self.albumBrowseId = item.albumBrowseId
        self.albumTitle = item.albumTitle ?? item.title
        self.artworkURL = item.artworkURL
        self.videoId = item.videoId
        self.isCurrentPlayerTrack = false
        self.isLiked = false
        self.engine = engine
        self.onOpenRoute = onOpenRoute
        self.onRemoveFromPlaylist = onRemoveFromPlaylist
    }

    init(
        style: TrackEllipsisMenuStyle,
        playerState: PlayerState,
        engine: YouTubeMusicEngine,
        onOpenRoute: ((NavigationRoute) -> Void)? = nil
    ) {
        let cachedTrack = engine.cache.track(for: playerState.videoId)
        let resolvedArtistId = !playerState.artistBrowseId.isEmpty
            ? playerState.artistBrowseId
            : (cachedTrack?.artistBrowseId ?? "")
        let resolvedAlbumId = !playerState.albumBrowseId.isEmpty
            ? playerState.albumBrowseId
            : (cachedTrack?.albumBrowseId ?? "")
        let resolvedAlbumTitle = !playerState.album.isEmpty
            ? playerState.album
            : (cachedTrack?.albumTitle ?? playerState.title)

        self.style = style
        self.artistBrowseId = resolvedArtistId.isEmpty ? nil : resolvedArtistId
        self.artistTitle = playerState.artist
        self.albumBrowseId = resolvedAlbumId.isEmpty ? nil : resolvedAlbumId
        self.albumTitle = resolvedAlbumTitle.isEmpty ? playerState.title : resolvedAlbumTitle
        self.artworkURL = playerState.artworkURL
        self.videoId = playerState.videoId.isEmpty ? nil : playerState.videoId
        self.isCurrentPlayerTrack = true
        self.isLiked = playerState.likeStatus == .like
        self.engine = engine
        self.onOpenRoute = onOpenRoute
        self.onRemoveFromPlaylist = nil
    }

    var body: some View {
        Menu {
            TrackActionsMenuContent(
                artistBrowseId: artistBrowseId,
                artistTitle: artistTitle,
                albumBrowseId: albumBrowseId,
                albumTitle: albumTitle,
                artworkURL: artworkURL,
                videoId: videoId,
                isCurrentPlayerTrack: isCurrentPlayerTrack,
                isLiked: isLiked,
                engine: engine,
                onOpenRoute: onOpenRoute,
                onRemoveFromPlaylist: onRemoveFromPlaylist
            )
        } label: {
            menuLabel
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .tint(tintColor)
        .fixedSize()
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var menuLabel: some View {
        switch style {
        case .rowSubtle:
            Image(systemName: AppSymbols.ellipsis)
                .font(.system(size: 14, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())

        case .playerBar(let isEnabled):
            Image(systemName: AppSymbols.ellipsis)
                .font(.system(size: 18, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isEnabled ? Color.primary.opacity(0.88) : Color.primary.opacity(0.32))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())

        case .fullScreenOverlay:
            Image(systemName: AppSymbols.ellipsis)
                .font(.system(size: 14, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.16), in: Circle())
        }
    }

    private var tintColor: Color {
        switch style {
        case .rowSubtle, .playerBar: return .primary
        case .fullScreenOverlay: return .white
        }
    }

    private var isDisabled: Bool {
        if case .playerBar(let isEnabled) = style {
            return !isEnabled
        }
        return false
    }
}

private extension TrackActionsMenuContent {
    init(
        artistBrowseId: String?,
        artistTitle: String,
        albumBrowseId: String?,
        albumTitle: String,
        artworkURL: String,
        videoId: String?,
        isCurrentPlayerTrack: Bool,
        isLiked: Bool,
        engine: YouTubeMusicEngine?,
        onOpenRoute: ((NavigationRoute) -> Void)?,
        onRemoveFromPlaylist: (() -> Void)?
    ) {
        self.artistBrowseId = artistBrowseId
        self.artistTitle = artistTitle
        self.albumBrowseId = albumBrowseId
        self.albumTitle = albumTitle
        self.artworkURL = artworkURL
        self.videoId = videoId
        self.isCurrentPlayerTrack = isCurrentPlayerTrack
        self.isLiked = isLiked
        self.engine = engine
        self.onOpenRoute = onOpenRoute
        self.onRemoveFromPlaylist = onRemoveFromPlaylist
    }
}
