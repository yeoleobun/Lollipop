import SwiftUI

/// Modeled after macOS 27 Apple Podcasts Search: centered capsule search field,
/// centered dark-active filter pills, and hairline-divided result rows with right-side play buttons.
struct SearchView: View {
    @Binding var query: String
    let engine: YouTubeMusicEngine
    let onOpenCollection: (NavigationRoute) -> Void

    @ViewState private var selectedFilter: SearchFilter = .all
    @ViewState private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Centered Search Capsule + Filter Pills
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: AppSymbols.search)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField(L10n.searchPlaceholder, text: $query)
                        .textFieldStyle(.plain)
                        .font(AppTypography.formBody)
                        .onSubmit { triggerSearch(immediate: true) }

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: AppSymbols.closeCircleFill)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: 360)
                .background(AppColors.searchFieldFill, in: Capsule())

                HStack(spacing: 6) {
                    ForEach(SearchFilter.allCases) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedFilter = filter
                            }
                            triggerSearch(immediate: true)
                        } label: {
                            Text(filter.title)
                        }
                        .buttonStyle(
                            FilterPillButtonStyle(
                                isSelected: selectedFilter == filter,
                                mode: .invertedPrimary
                            )
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, AppMetrics.pageHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 12)

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    L10n.searchPlaceholder,
                    systemImage: AppSymbols.search,
                    description: Text(L10n.searchDescription)
                )
                .pageCenteredState()
            } else if engine.isLoadingSearch && engine.searchSections.isEmpty {
                ProgressView(L10n.searching)
                    .pageCenteredState()
            } else if engine.searchSections.isEmpty {
                ContentUnavailableView.search(text: query)
                    .pageCenteredState()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(engine.searchSections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(AppTypography.searchSectionTitle)
                                    .padding(.top, 6)

                                VStack(spacing: 0) {
                                    ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, item in
                                        searchResultRow(item)
                                        if idx < section.items.count - 1 {
                                            Divider()
                                                .padding(.leading, 64)
                                                .opacity(0.45)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .pageScrollContent(top: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
        .onChange(of: query) { _, _ in
            triggerSearch(immediate: false)
        }
        .onAppear {
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && engine.searchSections.isEmpty {
                triggerSearch(immediate: true)
            }
        }
    }

    private func searchResultRow(_ item: MusicItem) -> some View {
        let isCurrent = item.videoId != nil && item.videoId == engine.playerState.videoId
        let isPlaying = isCurrent && engine.playerState.isPlaying

        return HStack(spacing: 14) {
            ArtworkView(
                urlString: item.artworkURL,
                size: AppMetrics.searchArtworkSize,
                cornerRadius: AppMetrics.searchArtworkCornerRadius,
                isCircular: item.kind == .artist
            )

            VStack(alignment: .leading, spacing: 3) {
                if let dur = item.durationText, !dur.isEmpty {
                    Text(dur)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(item.title)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? AppColors.accent : .primary)
                    .lineLimit(1)

                TrackMetadataLinksView(
                    item: item,
                    showAlbum: true,
                    fontSize: 12,
                    onOpenRoute: onOpenCollection
                )
            }

            Spacer(minLength: 12)

            if item.videoId != nil || item.artistBrowseId != nil || item.albumBrowseId != nil {
                TrackEllipsisMenuButton(
                    style: .rowSubtle,
                    item: item,
                    engine: engine,
                    onOpenRoute: onOpenCollection
                )
            }

            if item.videoId != nil || item.playlistId != nil {
                Button {
                    if isCurrent {
                        engine.togglePlayPause()
                    } else {
                        engine.play(item: item)
                    }
                } label: {
                    Image(systemName: isPlaying ? AppSymbols.pauseFill : AppSymbols.playFill)
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(
                    FloatingCircleIconButtonStyle(
                        size: 28,
                        foreground: AppColors.accent,
                        background: AnyShapeStyle(AppColors.hoverRowFill),
                        borderColor: nil,
                        shadowColor: .clear,
                        shadowRadius: 0,
                        shadowY: 0
                    )
                )
            } else {
                Image(systemName: AppSymbols.chevronRight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            MusicItemNavigator.handleRowTap(item, engine: engine, onOpenRoute: onOpenCollection)
        }
        .contextMenu {
            TrackActionsMenuContent(
                item: item,
                engine: engine,
                onOpenRoute: onOpenCollection
            )
        }
    }

    private func triggerSearch(immediate: Bool) {
        searchTask?.cancel()
        let currentQuery = query
        let currentFilter = selectedFilter
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(AppConstants.searchDebounceMilliseconds))
            }
            guard !Task.isCancelled else { return }
            await engine.search(query: currentQuery, filter: currentFilter)
        }
    }
}
