import SwiftUI

/// Full multi-column grid or full track list view opened when clicking a section header.
struct SectionGridView: View {
    let section: MusicSection
    let engine: YouTubeMusicEngine
    let onOpenRoute: (NavigationRoute) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    if let sub = section.subtitle, !sub.isEmpty {
                        Text(sub.uppercased())
                            .font(AppTypography.sectionEyebrow)
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                    }
                    Text(section.title)
                        .font(AppTypography.pageTitle)
                        .tracking(-0.4)
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
                        spacing: 24
                    ) {
                        ForEach(section.items) { item in
                            MediaCardView(
                                item: item,
                                size: AppMetrics.cardSectionGridSize,
                                onTap: {
                                    MusicItemNavigator.handleCardTap(item, engine: engine, onOpenRoute: onOpenRoute)
                                },
                                onPlay: { engine.play(item: item) },
                                onOpenRoute: onOpenRoute
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
                                    MusicItemNavigator.handleRowTap(item, engine: engine, onOpenRoute: onOpenRoute)
                                },
                                onOpenRoute: onOpenRoute
                            )
                        }
                    }
                }
            }
            .pageScrollContent()
        }
        .pageBackground()
    }
}
