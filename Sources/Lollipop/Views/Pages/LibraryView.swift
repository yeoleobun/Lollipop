import SwiftUI

struct LibraryView: View {
    let engine: YouTubeMusicEngine
    let onOpenCollection: (NavigationRoute) -> Void

    @ViewState private var selectedTab: LibraryTab = .songs

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.library)
                        .font(AppTypography.libraryTitle)
                        .tracking(-0.4)

                    Spacer()

                    Button {
                        Task { await engine.loadLibrary(browseId: selectedTab.browseId) }
                    } label: {
                        Image(systemName: AppSymbols.refresh)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.refresh(L10n.library))
                }

                // Filter pills (Songs / Albums / Artists)
                HStack(spacing: 8) {
                    ForEach(LibraryTab.allCases) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedTab = tab
                            }
                            Task { await engine.loadLibrary(browseId: tab.browseId) }
                        } label: {
                            Text(tab.title)
                        }
                        .buttonStyle(
                            FilterPillButtonStyle(
                                isSelected: selectedTab == tab,
                                mode: .accent
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, AppMetrics.pageHorizontalPadding)
            .padding(.top, AppMetrics.pageTopPadding)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Divider()
                    .padding(.horizontal, AppMetrics.pageHorizontalPadding)
                    .opacity(0.45)
            }

            if engine.isLoadingLibrary && engine.librarySections.isEmpty {
                ProgressView(L10n.loading(selectedTab.title))
                    .pageCenteredState()
            } else if engine.librarySections.isEmpty {
                ContentUnavailableView(
                    L10n.noItemsFound(selectedTab.title),
                    systemImage: AppSymbols.library,
                    description: Text(
                        engine.isSignedIn
                            ? L10n.savedItemsAppearHere(selectedTab.title)
                            : L10n.librarySignInPrompt
                    )
                )
                .pageCenteredState()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(engine.librarySections) { section in
                            VStack(alignment: .leading, spacing: 14) {
                                if !section.title.isEmpty
                                    && section.title != YouTubeMusicConstants.redundantLibrarySectionTitle {
                                    Text(section.title)
                                        .font(AppTypography.librarySectionTitle)
                                }

                                if section.layout == .carousel {
                                    LazyVGrid(
                                        columns: [
                                            GridItem(
                                                .adaptive(
                                                    minimum: AppMetrics.cardGridMinSize,
                                                    maximum: AppMetrics.cardGridMaxSize
                                                ),
                                                spacing: AppMetrics.carouselSpacing
                                            )
                                        ],
                                        spacing: 22
                                    ) {
                                        ForEach(section.items) { item in
                                            MediaCardView(
                                                item: item,
                                                size: AppMetrics.cardLibrarySize,
                                                onTap: {
                                                    MusicItemNavigator.handleCardTap(
                                                        item,
                                                        engine: engine,
                                                        onOpenRoute: onOpenCollection
                                                    )
                                                },
                                                onPlay: { engine.play(item: item) },
                                                onOpenRoute: onOpenCollection
                                            )
                                        }
                                    }
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
                                                    MusicItemNavigator.handleRowTap(
                                                        item,
                                                        engine: engine,
                                                        onOpenRoute: onOpenCollection
                                                    )
                                                },
                                                onOpenRoute: onOpenCollection
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .pageScrollContent(top: 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
        .task {
            await engine.loadLibrary(browseId: selectedTab.browseId)
        }
    }
}
