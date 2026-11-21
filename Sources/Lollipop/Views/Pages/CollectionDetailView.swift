import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CollectionDetailView: View {
    let browseId: String
    let fallbackTitle: String
    let fallbackArtworkURL: String
    let engine: YouTubeMusicEngine
    var autoPlay: Bool = false
    var autoPlayVideoId: String? = nil
    var onOpenRoute: ((NavigationRoute) -> Void)? = nil
    var onDeletedPlaylist: (() -> Void)? = nil

    @ViewState private var detail: CollectionDetail?
    @ViewState private var isLoading = true
    @ViewState private var hasAutoPlayed = false
    @ViewState private var showDeleteConfirm = false
    @ViewState private var isCoverHovered = false

    private var isEditablePlaylist: Bool {
        let norm = MusicCacheStore.normalizeCollectionBrowseId(browseId)
        guard YouTubeMusicConstants.isEditablePlaylistBrowseId(norm), engine.isSignedIn else {
            return false
        }
        if detail?.isEditable == true { return true }
        return engine.userPlaylists.contains { $0.id == norm }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppMetrics.detailSectionSpacing) {
                heroHeader

                if isLoading && detail == nil {
                    ProgressView(L10n.loadingTracks)
                        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                } else if let detail, !detail.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Text(L10n.songs)
                                .font(AppTypography.sectionTitle)
                            Text("\(detail.tracks.count)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 2) {
                            ForEach(Array(detail.tracks.enumerated()), id: \.element.id) { idx, track in
                                TrackRowView(
                                    item: track,
                                    index: idx,
                                    showArtwork: true,
                                    isCurrentTrack: track.videoId != nil && track.videoId == engine.playerState.videoId,
                                    isPlaying: engine.playerState.isPlaying,
                                    engine: engine,
                                    onTap: {
                                        engine.play(
                                            videoId: track.videoId ?? "",
                                            playlistId: track.playlistId ?? detail.playlistId
                                        )
                                    },
                                    onOpenRoute: onOpenRoute,
                                    onRemoveFromPlaylist: (isEditablePlaylist && track.setVideoId != nil && track.videoId != nil)
                                        ? { removeTrack(track) }
                                        : nil
                                )
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label(L10n.noTracksFound, systemImage: AppSymbols.playlist)
                    } description: {
                        Text(engine.isSignedIn ? L10n.collectionEmptySignedIn : L10n.collectionEmptySignedOut)
                    } actions: {
                        Button(L10n.reload) {
                            Task { await reloadDetail() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
                }
            }
            .pageScrollContent()
        }
        .pageBackground()
        .task(id: browseId) {
            hasAutoPlayed = false
            if let cached = engine.cache.collection(for: browseId) {
                detail = cached
                isLoading = false
                triggerAutoPlayIfNeeded()
                return
            }
            detail = nil
            isLoading = true
            detail = await engine.fetchCollection(browseId: browseId)
            isLoading = false
            triggerAutoPlayIfNeeded()
        }
        .onChange(of: engine.playlistMutationCounter) { _, _ in
            let currentNorm = MusicCacheStore.normalizeCollectionBrowseId(browseId)
            let mutatedNorm = MusicCacheStore.normalizeCollectionBrowseId(engine.lastMutatedPlaylistId ?? "")
            let detailPlaylistNorm = detail?.playlistId.map { MusicCacheStore.normalizeCollectionBrowseId($0) }
            if !mutatedNorm.isEmpty && (mutatedNorm == currentNorm || mutatedNorm == detailPlaylistNorm) {
                Task { await reloadDetail() }
            }
        }
    }

    private func reloadDetail() async {
        isLoading = true
        detail = await engine.fetchCollection(browseId: browseId, forceRefresh: true)
        isLoading = false
        triggerAutoPlayIfNeeded()
    }

    private func triggerAutoPlayIfNeeded() {
        guard autoPlay, !hasAutoPlayed else { return }
        if let vid = autoPlayVideoId, !vid.isEmpty {
            hasAutoPlayed = true
            let matched = detail?.tracks.first(where: { $0.videoId == vid })
            engine.play(videoId: vid, playlistId: matched?.playlistId ?? detail?.playlistId)
            return
        }
        guard let detail, !detail.tracks.isEmpty else { return }
        hasAutoPlayed = true
        playFirst(shuffled: false)
    }

    private var heroHeader: some View {
        let remoteArtwork = detail?.artworkURL.isEmpty == false ? (detail?.artworkURL ?? fallbackArtworkURL) : fallbackArtworkURL
        let artwork = engine.cache.resolvedPlaylistArtwork(
            for: browseId,
            remoteArtwork: remoteArtwork,
            tracks: detail?.tracks ?? []
        )
        let title = detail?.title.isEmpty == false ? (detail?.title ?? fallbackTitle) : fallbackTitle

        return ZStack(alignment: .bottomLeading) {
            AmbientArtworkBackdrop(
                artworkURL: artwork,
                style: .heroBanner(
                    height: AppMetrics.heroBannerHeight,
                    cornerRadius: AppMetrics.heroCornerRadius
                )
            )

            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    ArtworkView(
                        urlString: artwork,
                        size: AppMetrics.heroArtworkSize,
                        cornerRadius: AppMetrics.heroArtworkCornerRadius
                    )
                    .shadow(color: .black.opacity(0.24), radius: 18, y: 8)

                    if isEditablePlaylist && isCoverHovered {
                        RoundedRectangle(cornerRadius: AppMetrics.heroArtworkCornerRadius, style: .continuous)
                            .fill(.black.opacity(0.45))
                            .frame(width: AppMetrics.heroArtworkSize, height: AppMetrics.heroArtworkSize)
                            .overlay {
                                VStack(spacing: 6) {
                                    Image(systemName: AppSymbols.changeCover)
                                        .font(.system(size: 24, weight: .medium))
                                    Text(L10n.changeCover)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                            }
                            .transition(.opacity)
                    }
                }
                .onHover { hovering in
                    withAnimation(AppAnimations.fastHover) {
                        isCoverHovered = hovering
                    }
                }
                .onTapGesture {
                    if isEditablePlaylist {
                        pickCustomCover()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(AppTypography.heroTitle)
                        .lineLimit(2)

                    if let artistName = detail?.artistName, !artistName.isEmpty {
                        if let artistId = detail?.artistBrowseId, let onOpenRoute {
                            Button {
                                onOpenRoute(NavigationRoute(browseId: artistId, title: artistName, artworkURL: artwork))
                            } label: {
                                HStack(spacing: 4) {
                                    Text(artistName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppColors.accent)
                                    Image(systemName: AppSymbols.chevronRight)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppColors.accent.opacity(0.75))
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(artistName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                        }
                    }

                    if let sub = detail?.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let desc = detail?.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    heroActionButtons
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(22)
        }
        .alert(L10n.deletePlaylistConfirmTitle, isPresented: $showDeleteConfirm) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.delete, role: .destructive) {
                Task {
                    let ok = await engine.deletePlaylist(playlistId: detail?.playlistId ?? browseId)
                    if ok {
                        onDeletedPlaylist?()
                    }
                }
            }
        } message: {
            Text(L10n.deletePlaylistConfirmMsg)
        }
    }

    private var heroActionButtons: some View {
        let isDisabled = detail?.tracks.isEmpty ?? true

        return HStack(spacing: 10) {
            Button {
                playFirst(shuffled: false)
            } label: {
                Label(L10n.play, systemImage: AppSymbols.playFill)
            }
            .buttonStyle(PrimaryCapsuleButtonStyle(horizontalPadding: 20, verticalPadding: 8))
            .disabled(isDisabled)

            Button {
                playFirst(shuffled: true)
            } label: {
                Label(L10n.shuffle, systemImage: AppSymbols.shuffle)
            }
            .buttonStyle(SecondaryCapsuleButtonStyle(horizontalPadding: 18, verticalPadding: 8))
            .disabled(isDisabled)

            if isEditablePlaylist {
                Button {
                    engine.presentEditPlaylist(
                        playlistId: detail?.playlistId ?? browseId,
                        title: detail?.title ?? fallbackTitle,
                        description: detail?.description ?? ""
                    )
                } label: {
                    Label(L10n.edit, systemImage: AppSymbols.pencil)
                }
                .buttonStyle(SecondaryCapsuleButtonStyle(horizontalPadding: 16, verticalPadding: 8))

                Menu {
                    Button {
                        pickCustomCover()
                    } label: {
                        Label(L10n.changeCover, systemImage: AppSymbols.changeCover)
                    }

                    if engine.cache.hasCustomPlaylistCover(for: browseId) {
                        Button {
                            engine.cache.removeCustomPlaylistCover(for: browseId)
                        } label: {
                            Label(L10n.resetCover, systemImage: AppSymbols.reset)
                        }
                    }

                    Button {
                        Task { await reloadDetail() }
                    } label: {
                        Label(L10n.reload, systemImage: AppSymbols.refresh)
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(L10n.deletePlaylist, systemImage: AppSymbols.trash)
                    }
                } label: {
                    Image(systemName: AppSymbols.ellipsis)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.subtleFill, in: Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
    }

    private func pickCustomCover() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            engine.cache.setCustomPlaylistCover(for: browseId, from: url)
        }
    }

    private func removeTrack(_ track: MusicItem) {
        guard let vid = track.videoId, let setVid = track.setVideoId else { return }
        let pid = detail?.playlistId ?? browseId
        // Optimistic UI update
        if var updated = detail {
            updated.tracks.removeAll { $0.id == track.id }
            detail = updated
            engine.cache.updateCollection(updated, for: browseId)
        }
        Task {
            let ok = await engine.removeTrackFromPlaylist(playlistId: pid, videoId: vid, setVideoId: setVid)
            if !ok {
                detail = await engine.fetchCollection(browseId: browseId, forceRefresh: true)
            }
        }
    }

    private func playFirst(shuffled: Bool) {
        guard let detail, !detail.tracks.isEmpty else { return }
        let chosen = shuffled ? detail.tracks.randomElement() : detail.tracks.first
        if let track = chosen, let vid = track.videoId {
            engine.play(videoId: vid, playlistId: track.playlistId ?? detail.playlistId)
        }
    }
}
