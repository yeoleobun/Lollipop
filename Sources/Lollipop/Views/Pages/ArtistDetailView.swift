import SwiftUI

struct ArtistDetailView: View {
    let browseId: String
    let fallbackName: String
    let fallbackArtworkURL: String
    let engine: YouTubeMusicEngine
    let onOpenRoute: (NavigationRoute) -> Void
    var onOpenSection: ((MusicSection) -> Void)? = nil

    @ViewState private var detail: ArtistDetail?
    @ViewState private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppMetrics.detailSectionSpacing) {
                heroHeader

                if isLoading && detail == nil {
                    ProgressView(L10n.loadingArtist)
                        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                } else if let detail {
                    ForEach(detail.sections) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeaderView(
                                title: section.title,
                                onTap: onOpenSection.map { callback in { callback(section) } }
                            )

                            if section.layout == .carousel {
                                HorizontalCarouselView(
                                    items: section.items,
                                    onTap: { item in
                                        MusicItemNavigator.handleCardTap(item, engine: engine, onOpenRoute: onOpenRoute)
                                    },
                                    onPlay: { engine.play(item: $0) },
                                    onOpenRoute: onOpenRoute
                                )
                            } else {
                                VStack(spacing: 2) {
                                    ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, item in
                                        TrackRowView(
                                            item: item,
                                            index: idx,
                                            showArtwork: true,
                                            isCurrentTrack: item.videoId != nil && item.videoId == engine.playerState.videoId,
                                            isPlaying: engine.playerState.isPlaying,
                                            engine: engine,
                                            onTap: {
                                                MusicItemNavigator.handleRowTap(item, engine: engine, onOpenRoute: onOpenRoute)
                                            },
                                            onOpenRoute: onOpenRoute
                                        )
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label(L10n.artistUnavailable, systemImage: AppSymbols.artistUnavailable)
                    } description: {
                        Text(L10n.checkConnectionTryAgain)
                    } actions: {
                        Button(L10n.reload) {
                            Task {
                                isLoading = true
                                detail = await engine.fetchArtist(browseId: browseId, forceRefresh: true)
                                isLoading = false
                            }
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
            if let cached = engine.cache.artist(for: browseId) {
                detail = cached
                isLoading = false
                return
            }
            detail = nil
            isLoading = true
            detail = await engine.fetchArtist(browseId: browseId)
            isLoading = false
        }
    }

    private var heroHeader: some View {
        let artwork = detail?.artworkURL.isEmpty == false ? (detail?.artworkURL ?? fallbackArtworkURL) : fallbackArtworkURL
        let name = detail?.name.isEmpty == false ? (detail?.name ?? fallbackName) : fallbackName

        return ZStack(alignment: .bottomLeading) {
            AmbientArtworkBackdrop(
                artworkURL: artwork,
                style: .heroBanner(
                    height: AppMetrics.artistHeroBannerHeight,
                    cornerRadius: AppMetrics.heroCornerRadius
                )
            )

            HStack(alignment: .center, spacing: 24) {
                ArtworkView(
                    urlString: artwork,
                    size: AppMetrics.artistHeroArtworkSize,
                    cornerRadius: AppMetrics.artistHeroArtworkSize / 2,
                    isCircular: true
                )
                .shadow(color: .black.opacity(0.24), radius: 18, y: 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(AppTypography.artistHeroTitle)
                        .lineLimit(2)

                    if let subs = detail?.subscribers, !subs.isEmpty {
                        Text(subs)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if let desc = detail?.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }

                    heroActionButtons
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(22)
        }
    }

    private var playableSongs: [MusicItem] {
        guard let detail else { return [] }
        return detail.sections.flatMap(\.items).filter { $0.videoId != nil }
    }

    private var canShuffle: Bool {
        guard let detail else { return false }
        return !(detail.shufflePlaylistId?.isEmpty ?? true)
            || !(detail.shuffleVideoId?.isEmpty ?? true)
            || !playableSongs.isEmpty
    }

    private var canStartRadio: Bool {
        guard let detail else { return false }
        return !(detail.radioPlaylistId?.isEmpty ?? true)
            || !(detail.radioVideoId?.isEmpty ?? true)
            || !playableSongs.isEmpty
    }

    private var heroActionButtons: some View {
        HStack(spacing: 10) {
            Button {
                playArtistShuffle()
            } label: {
                Label(L10n.shuffle, systemImage: AppSymbols.shuffle)
            }
            .buttonStyle(PrimaryCapsuleButtonStyle(horizontalPadding: 20, verticalPadding: 8))
            .disabled(!canShuffle)

            Button {
                playArtistRadio()
            } label: {
                Label(L10n.artistRadio, systemImage: AppSymbols.radio)
            }
            .buttonStyle(SecondaryCapsuleButtonStyle(horizontalPadding: 18, verticalPadding: 8))
            .disabled(!canStartRadio)
        }
    }

    private func playArtistShuffle() {
        guard let detail else { return }
        if (detail.shufflePlaylistId?.isEmpty == false) || (detail.shuffleVideoId?.isEmpty == false) {
            engine.play(
                videoId: detail.shuffleVideoId ?? "",
                playlistId: detail.shufflePlaylistId,
                params: detail.shuffleParams
            )
            return
        }
        if let song = playableSongs.randomElement(), let vid = song.videoId {
            engine.play(videoId: vid, playlistId: song.playlistId)
        }
    }

    private func playArtistRadio() {
        guard let detail else { return }
        if (detail.radioPlaylistId?.isEmpty == false) || (detail.radioVideoId?.isEmpty == false) {
            engine.play(
                videoId: detail.radioVideoId ?? "",
                playlistId: detail.radioPlaylistId,
                params: detail.radioParams
            )
            return
        }
        if let first = playableSongs.first, let vid = first.videoId {
            engine.startRadio(forVideoId: vid)
        }
    }
}
