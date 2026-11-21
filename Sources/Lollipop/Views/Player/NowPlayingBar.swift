import SwiftUI

/// Compact, centered floating Liquid Glass Capsule player bar modeled directly
/// on macOS 27 Apple Podcasts / Apple Music.
struct NowPlayingBar: View {
    let engine: YouTubeMusicEngine
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab
    var onOpenRoute: ((NavigationRoute) -> Void)? = nil

    @ViewState private var isScrubbing = false
    @ViewState private var scrubTime: Double = 0

    private var state: PlayerState { engine.playerState }

    var body: some View {
        HStack(spacing: 12) {
            transportControls
            trackInfoCenter
            inspectorAndVolumeControls
        }
        .padding(.horizontal, AppMetrics.playerBarHorizontalPadding)
        .frame(height: AppMetrics.playerBarHeight)
        .liquidGlassCapsule(interactive: false)
        .shadow(color: .black.opacity(0.14), radius: 20, y: 8)
        .padding(.horizontal, AppMetrics.playerBarOuterHorizontalMargin)
        .padding(.bottom, AppMetrics.playerBarBottomMargin)
    }

    // MARK: - Left: Transport Controls

    private var transportControls: some View {
        HStack(spacing: 2) {
            Button {
                engine.toggleShuffle()
            } label: {
                Image(systemName: AppSymbols.shuffle)
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(
                PlayerIconButtonStyle(
                    size: 28,
                    foreground: state.isShuffled ? AppColors.accent : .secondary
                )
            )
            .help(L10n.shuffle)

            Button {
                engine.previousTrack()
            } label: {
                Image(systemName: AppSymbols.backwardFill)
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(PlayerIconButtonStyle(size: 28))
            .help(L10n.previousTrack)

            Button {
                engine.togglePlayPause()
            } label: {
                Image(systemName: state.isPlaying ? AppSymbols.pauseFill : AppSymbols.playFill)
                    .font(.system(size: 20, weight: .bold))
            }
            .buttonStyle(PlayerIconButtonStyle(size: 36))
            .help(state.isPlaying ? L10n.pause : L10n.play)

            Button {
                engine.nextTrack()
            } label: {
                Image(systemName: AppSymbols.forwardFill)
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(PlayerIconButtonStyle(size: 28))
            .help(L10n.nextTrack)

            Button {
                engine.cycleRepeat()
            } label: {
                Image(systemName: state.repeatMode.systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(
                PlayerIconButtonStyle(
                    size: 28,
                    foreground: state.repeatMode == .off ? .secondary : AppColors.accent
                )
            )
            .help(L10n.repeatMode)
        }
    }

    // MARK: - Center: Artwork + Track Info + Ellipsis + Scrubber

    private var trackInfoCenter: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                withAnimation(AppAnimations.overlaySpring) {
                    showInspector = true
                }
            } label: {
                ArtworkView(
                    urlString: state.artworkURL,
                    size: 34,
                    cornerRadius: 7
                )
                .shadow(color: .black.opacity(0.16), radius: 2.5, y: 1)
            }
            .buttonStyle(.plain)
            .help(L10n.playingNext)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(state.hasTrack && !state.title.isEmpty ? state.title : L10n.notPlaying)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(state.hasTrack ? .primary : .secondary)
                    .lineLimit(1)

                if state.hasTrack && !state.artistBrowseId.isEmpty, let onOpenRoute {
                    Button {
                        onOpenRoute(
                            NavigationRoute(
                                browseId: state.artistBrowseId,
                                title: state.artist,
                                artworkURL: state.artworkURL
                            )
                        )
                    } label: {
                        Text(state.artist)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.goToArtist)
                } else {
                    Text(state.hasTrack && !state.artist.isEmpty ? state.artist : L10n.pickASong)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            TrackEllipsisMenuButton(
                style: .playerBar(isEnabled: state.hasTrack),
                playerState: state,
                engine: engine,
                onOpenRoute: onOpenRoute
            )
        }
        .frame(minWidth: 320, maxWidth: 385)
        .overlay(alignment: .bottom) {
            PlaybackScrubberView(
                value: isScrubbing ? scrubTime : state.currentTime,
                total: max(state.duration, 1),
                style: .compactBar,
                onEditingChanged: { editing, newValue in
                    isScrubbing = editing
                    scrubTime = newValue
                    if !editing {
                        engine.seek(to: newValue)
                    }
                }
            )
            .disabled(!state.hasTrack || state.duration <= 0)
            .offset(y: 11.5)
        }
        .contextMenu {
            TrackActionsMenuContent(
                playerState: state,
                engine: engine,
                onOpenRoute: onOpenRoute
            )
        }
    }

    // MARK: - Right: Lyrics, Playing Next, Volume Popover

    private var inspectorAndVolumeControls: some View {
        HStack(spacing: 2) {
            inspectorButton(tab: .lyrics, symbol: AppSymbols.lyricsQuote)
            inspectorButton(tab: .queue, symbol: AppSymbols.queueList)
            VolumeControlView(engine: engine, style: .popoverButton)
        }
    }

    private func inspectorButton(tab: InspectorTab, symbol: String) -> some View {
        let active = isTabActive(tab)
        return Button {
            toggleInspector(tab)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
        }
        .buttonStyle(
            PlayerIconButtonStyle(
                size: 36,
                foreground: active ? AppColors.accent : .primary.opacity(0.82),
                activeBackground: active ? AppColors.accent.opacity(0.15) : .clear
            )
        )
        .help(tab.title)
    }

    private func isTabActive(_ tab: InspectorTab) -> Bool {
        showInspector && inspectorTab == tab
    }

    private func toggleInspector(_ tab: InspectorTab) {
        withAnimation(AppAnimations.overlaySpring) {
            if showInspector && inspectorTab == tab {
                showInspector = false
            } else {
                inspectorTab = tab
                showInspector = true
            }
        }
    }
}
