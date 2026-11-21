import SwiftUI

struct BrowseView: View {
    let title: String
    let sections: [MusicSection]
    let isLoading: Bool
    let engine: YouTubeMusicEngine
    let onOpenCollection: (NavigationRoute) -> Void
    var onOpenSection: ((MusicSection) -> Void)? = nil
    let onRefresh: () async -> Void

    var body: some View {
        Group {
            if sections.isEmpty {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, AppMetrics.pageHorizontalPadding)
                        .padding(.top, AppMetrics.pageTopPadding)

                    if isLoading {
                        loadingPlaceholder
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                        header

                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                    .pageScrollContent()
                }
            }
        }
        .pageBackground()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTypography.pageTitle)
                .tracking(-0.4)

            Spacer()

            Button {
                Task { await onRefresh() }
            } label: {
                Image(systemName: AppSymbols.refresh)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.refresh(title))
        }
    }

    @ViewBuilder
    private func sectionView(_ section: MusicSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(
                title: section.title,
                subtitle: section.subtitle,
                onTap: onOpenSection.map { callback in { callback(section) } }
            )

            switch section.layout {
            case .carousel:
                HorizontalCarouselView(
                    items: section.items,
                    onTap: { item in
                        MusicItemNavigator.handleCardTap(item, engine: engine, onOpenRoute: onOpenCollection)
                    },
                    onPlay: { engine.play(item: $0) },
                    onOpenRoute: onOpenCollection
                )

            case .quickPicks:
                quickPicksGrid(items: section.items)

            case .list:
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
                                MusicItemNavigator.handleRowTap(item, engine: engine, onOpenRoute: onOpenCollection)
                            },
                            onOpenRoute: onOpenCollection
                        )
                    }
                }
            }
        }
    }

    private func quickPicksGrid(items: [MusicItem]) -> some View {
        let rows = Array(
            repeating: GridItem(.fixed(AppMetrics.quickPicksRowHeight), spacing: 6),
            count: min(4, max(1, items.count))
        )
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 16) {
                ForEach(items) { item in
                    TrackRowView(
                        item: item,
                        showArtwork: true,
                        isCurrentTrack: item.videoId != nil && item.videoId == engine.playerState.videoId,
                        isPlaying: engine.playerState.isPlaying,
                        engine: engine,
                        onTap: {
                            MusicItemNavigator.handleRowTap(item, engine: engine, onOpenRoute: onOpenCollection)
                        },
                        onOpenRoute: onOpenCollection
                    )
                    .frame(width: AppMetrics.quickPicksWidth)
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
            Text(engine.isEngineLoaded ? L10n.loading(title) : L10n.startingAudioEngine)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .pageCenteredState()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: AppSymbols.emptyBrowse)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)

            Text(L10n.nothingLoadedYet)
                .font(.system(size: 16, weight: .semibold))

            if let err = engine.errorMessage {
                Text(err)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 12) {
                Button(L10n.reload) {
                    Task { await onRefresh() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                if !engine.playerState.isSignedIn {
                    Button(L10n.signIn) {
                        engine.openSignIn()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .pageCenteredState()
    }
}
