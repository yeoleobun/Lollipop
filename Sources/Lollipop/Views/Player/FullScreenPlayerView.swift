import SwiftUI

/// Full-window immersive Now Playing overlay modeled directly on macOS 27 Apple Podcasts / Apple Music:
/// Rich blurred album-art backdrop, top-left close button, top-right volume slider,
/// left-side large artwork + transport controls, right-side Synced Lyrics or Up Next Queue,
/// and bottom-right floating frosted toggle pill.
struct FullScreenPlayerView: View {
    let engine: YouTubeMusicEngine
    @Binding var selectedTab: InspectorTab
    let onClose: () -> Void
    let onOpenRoute: (NavigationRoute) -> Void

    @ViewState private var isScrubbing = false
    @ViewState private var scrubTime: Double = 0
    @ViewState private var isRefreshing = false

    private var state: PlayerState { engine.playerState }

    var body: some View {
        ZStack {
            AmbientArtworkBackdrop(artworkURL: state.artworkURL, style: .fullScreen)

            VStack(spacing: 0) {
                topBar

                GeometryReader { geo in
                    let artSize = min(380, max(250, geo.size.height * 0.50))
                    let inspectorWidth = min(460, max(320, geo.size.width * 0.42))

                    HStack(spacing: 48) {
                        leftPlayerColumn(artSize: artSize)
                            .frame(maxWidth: .infinity)

                        rightInspectorColumn
                            .frame(width: inspectorWidth, alignment: .leading)
                            .frame(maxHeight: .infinity)
                            .padding(.bottom, 76)
                            .animation(AppAnimations.standard, value: selectedTab)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.leading, 48)
                    .padding(.trailing, 72)
                }
            }

            bottomTogglePill
        }
        .onAppear {
            if !state.videoId.isEmpty && (engine.queue.isEmpty || engine.lyrics == nil) {
                refreshNow()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: AppSymbols.close)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .liquidGlassCapsule(interactive: true)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .padding(.leading, AppMetrics.trafficLightsLeadingInset + 4)

            Spacer()

            VolumeControlView(engine: engine, style: .inlinePill)
                .padding(.trailing, 16)
        }
        .padding(.top, 10)
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Left Column (Artwork, Mini Metadata Card, Scrubber, Transport)

    private func leftPlayerColumn(artSize: CGFloat) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            ArtworkView(
                urlString: state.artworkURL,
                size: artSize,
                cornerRadius: 16
            )
            .shadow(color: .black.opacity(0.45), radius: 32, y: 16)

            VStack(spacing: 16) {
                miniMetadataCard
                scrubberSection
                transportControls
            }
            .frame(width: artSize)

            Spacer(minLength: 16)
        }
    }

    private var miniMetadataCard: some View {
        let cachedTrack = engine.cache.track(for: state.videoId)
        let resolvedArtistId = !state.artistBrowseId.isEmpty ? state.artistBrowseId : (cachedTrack?.artistBrowseId ?? "")
        let resolvedAlbumId = !state.albumBrowseId.isEmpty ? state.albumBrowseId : (cachedTrack?.albumBrowseId ?? "")
        let resolvedAlbumTitle = !state.album.isEmpty ? state.album : (cachedTrack?.albumTitle ?? "")

        return HStack(alignment: .center, spacing: 12) {
            ArtworkView(
                urlString: state.artworkURL,
                size: 46,
                cornerRadius: 9
            )
            .shadow(color: .black.opacity(0.28), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                if state.hasTrack && !resolvedAlbumTitle.isEmpty {
                    if !resolvedAlbumId.isEmpty {
                        Button {
                            onOpenRoute(
                                NavigationRoute(
                                    browseId: resolvedAlbumId,
                                    title: resolvedAlbumTitle,
                                    artworkURL: state.artworkURL
                                )
                            )
                        } label: {
                            Text(resolvedAlbumTitle)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.58))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.goToAlbum)
                    } else {
                        Text(resolvedAlbumTitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }
                }

                Text(state.hasTrack && !state.title.isEmpty ? state.title : L10n.notPlaying)
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if state.hasTrack && !resolvedArtistId.isEmpty {
                    Button {
                        onOpenRoute(
                            NavigationRoute(
                                browseId: resolvedArtistId,
                                title: state.artist,
                                artworkURL: state.artworkURL
                            )
                        )
                    } label: {
                        Text(state.artist)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.goToArtist)
                } else {
                    Text(state.hasTrack ? state.artist : L10n.pickASong)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if state.hasTrack {
                TrackEllipsisMenuButton(
                    style: .fullScreenOverlay,
                    playerState: state,
                    engine: engine,
                    onOpenRoute: onOpenRoute
                )
            }
        }
    }

    private var scrubberSection: some View {
        VStack(spacing: 6) {
            PlaybackScrubberView(
                value: isScrubbing ? scrubTime : state.currentTime,
                total: max(state.duration, 1),
                style: .fullScreen,
                onEditingChanged: { editing, newValue in
                    isScrubbing = editing
                    scrubTime = newValue
                    if !editing {
                        engine.seek(to: newValue)
                    }
                }
            )
            .disabled(!state.hasTrack || state.duration <= 0)

            HStack {
                Text(TimeFormatter.string(from: isScrubbing ? scrubTime : state.currentTime))
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                let remaining = max(0, state.duration - (isScrubbing ? scrubTime : state.currentTime))
                Text("-\(TimeFormatter.string(from: remaining))")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 28) {
            Button {
                engine.toggleShuffle()
            } label: {
                Image(systemName: AppSymbols.shuffle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state.isShuffled ? AppColors.accent : .white.opacity(0.75))
            }
            .buttonStyle(.plain)

            Button {
                engine.previousTrack()
            } label: {
                Image(systemName: AppSymbols.backwardFill)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                engine.togglePlayPause()
            } label: {
                Image(systemName: state.isPlaying ? AppSymbols.pauseFill : AppSymbols.playFill)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Button {
                engine.nextTrack()
            } label: {
                Image(systemName: AppSymbols.forwardFill)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                engine.cycleRepeat()
            } label: {
                Image(systemName: state.repeatMode.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state.repeatMode == .off ? .white.opacity(0.75) : AppColors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Right Column & Toggle Pill

    @ViewBuilder
    private var rightInspectorColumn: some View {
        switch selectedTab {
        case .lyrics:
            PlayerLyricsView(
                lyrics: engine.lyrics,
                currentTime: state.currentTime,
                hasTrack: state.hasTrack,
                isRefreshing: isRefreshing,
                onSeek: { engine.seek(to: $0) }
            )
            .transition(.opacity)

        case .queue:
            PlayerQueueView(
                queue: engine.queue,
                currentVideoId: state.videoId,
                isPlaying: state.isPlaying,
                isRefreshing: isRefreshing,
                onPlayTrack: { engine.play(item: $0) },
                onRefresh: refreshNow
            )
            .transition(.opacity)
        }
    }

    private var bottomTogglePill: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    togglePillButton(tab: .lyrics, systemImage: AppSymbols.lyricsQuote)
                    togglePillButton(tab: .queue, systemImage: AppSymbols.queueList)
                }
                .padding(4)
                .liquidGlassCapsule(interactive: true)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func togglePillButton(tab: InspectorTab, systemImage: String) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? Color.black.opacity(0.88) : Color.white.opacity(0.85))
                .frame(width: 34, height: 30)
                .background(isActive ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    private func refreshNow() {
        let vid = state.videoId
        guard !vid.isEmpty else { return }
        isRefreshing = true
        Task {
            await engine.refreshQueueAndLyrics(videoId: vid)
            isRefreshing = false
        }
    }
}
