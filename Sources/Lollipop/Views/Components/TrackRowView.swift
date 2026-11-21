import SwiftUI

struct TrackRowView: View {
    let item: MusicItem
    var index: Int? = nil
    var showArtwork: Bool = true
    var isCurrentTrack: Bool = false
    var isPlaying: Bool = false
    var engine: YouTubeMusicEngine? = nil
    let onTap: () -> Void
    var onOpenRoute: ((NavigationRoute) -> Void)? = nil
    var onRemoveFromPlaylist: (() -> Void)? = nil

    @ViewState private var isHovered = false

    private var hasMenuActions: Bool {
        item.videoId != nil
            || item.artistBrowseId != nil
            || item.albumBrowseId != nil
            || onRemoveFromPlaylist != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            leadingArtworkOrIndex

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(AppTypography.trackTitle(isCurrent: isCurrentTrack))
                        .foregroundStyle(isCurrentTrack ? AppColors.accent : .primary)
                        .lineLimit(1)

                    if item.isExplicit {
                        ExplicitBadgeView()
                    }
                }

                TrackMetadataLinksView(
                    item: item,
                    showAlbum: true,
                    fontSize: 12,
                    onOpenRoute: onOpenRoute
                )
            }

            Spacer(minLength: 8)

            if let album = item.albumTitle,
               !album.isEmpty,
               item.artistName == nil || item.albumBrowseId == nil {
                if let albumId = item.albumBrowseId, let onOpenRoute {
                    HoverLinkText(text: album) {
                        onOpenRoute(
                            NavigationRoute(browseId: albumId, title: album, artworkURL: item.artworkURL)
                        )
                    }
                    .frame(maxWidth: AppMetrics.maxAlbumLabelWidth, alignment: .leading)
                } else {
                    Text(album)
                        .font(AppTypography.trackMeta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: AppMetrics.maxAlbumLabelWidth, alignment: .leading)
                }
            }

            if isHovered && hasMenuActions {
                TrackEllipsisMenuButton(
                    style: .rowSubtle,
                    item: item,
                    engine: engine,
                    onOpenRoute: onOpenRoute,
                    onRemoveFromPlaylist: onRemoveFromPlaylist
                )
            }

            if let duration = item.durationText, !duration.isEmpty {
                Text(duration)
                    .font(AppTypography.trackDuration)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, AppMetrics.trackRowHorizontalPadding)
        .padding(.vertical, AppMetrics.trackRowVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.trackRowCornerRadius, style: .continuous)
                .fill(backgroundFill)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(perform: onTap)
        .contextMenu {
            TrackActionsMenuContent(
                item: item,
                engine: engine,
                onOpenRoute: onOpenRoute,
                onRemoveFromPlaylist: onRemoveFromPlaylist
            )
        }
    }

    @ViewBuilder
    private var leadingArtworkOrIndex: some View {
        if let index, !showArtwork {
            ZStack {
                if isCurrentTrack {
                    EqualizerBarsView(isPlaying: isPlaying)
                } else if isHovered {
                    Image(systemName: AppSymbols.playFill)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                } else {
                    Text("\(index + 1)")
                        .font(AppTypography.trackIndex)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 26, alignment: .center)
        } else if showArtwork {
            ZStack {
                ArtworkView(
                    urlString: item.artworkURL,
                    size: AppMetrics.trackArtworkSize,
                    cornerRadius: AppMetrics.trackArtworkCornerRadius
                )

                if isCurrentTrack || isHovered {
                    RoundedRectangle(
                        cornerRadius: AppMetrics.trackArtworkCornerRadius,
                        style: .continuous
                    )
                    .fill(.black.opacity(0.45))
                    .frame(
                        width: AppMetrics.trackArtworkSize,
                        height: AppMetrics.trackArtworkSize
                    )

                    if isCurrentTrack {
                        EqualizerBarsView(isPlaying: isPlaying)
                    } else {
                        Image(systemName: AppSymbols.playFill)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var backgroundFill: Color {
        if isCurrentTrack {
            return AppColors.activeTrackRowFill
        }
        if isHovered {
            return AppColors.hoverRowFill
        }
        if let index, index.isMultiple(of: 2) {
            return AppColors.zebraRowFill
        }
        return .clear
    }
}
