import SwiftUI

struct MediaCardView: View {
    let item: MusicItem
    var size: CGFloat = AppMetrics.cardDefaultSize
    let onTap: () -> Void
    let onPlay: () -> Void
    var onOpenRoute: ((NavigationRoute) -> Void)? = nil

    @ViewState private var isHovered = false

    private var isArtist: Bool {
        item.kind == .artist
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(
                    urlString: item.artworkURL,
                    size: size,
                    cornerRadius: AppMetrics.cardCornerRadius,
                    isCircular: isArtist
                )
                .mediaCardElevation(
                    isHovered: isHovered,
                    isCircular: isArtist,
                    cornerRadius: AppMetrics.cardCornerRadius
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

                if isHovered && (item.videoId != nil || item.playlistId != nil) {
                    Button(action: onPlay) {
                        Image(systemName: AppSymbols.playFill)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(
                        FloatingCircleIconButtonStyle(
                            size: 36,
                            foreground: .white,
                            background: AnyShapeStyle(AppColors.accent),
                            borderColor: nil,
                            shadowColor: .black.opacity(0.3),
                            shadowRadius: 6,
                            shadowY: 2
                        )
                    )
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }

            VStack(alignment: isArtist ? .center : .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if item.isExplicit {
                        ExplicitBadgeView()
                    }
                }

                TrackMetadataLinksView(
                    item: item,
                    showAlbum: item.kind != .album,
                    fontSize: 12,
                    onOpenRoute: isArtist ? nil : onOpenRoute
                )
            }
            .frame(width: size, alignment: isArtist ? .center : .leading)
        }
        .onHover { hovering in
            withAnimation(AppAnimations.fastHover) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if let artistId = item.artistBrowseId, let onOpenRoute {
                Button {
                    onOpenRoute(
                        NavigationRoute(
                            browseId: artistId,
                            title: isArtist ? item.title : item.subtitle,
                            artworkURL: item.artworkURL
                        )
                    )
                } label: {
                    Label(L10n.goToArtist, systemImage: AppSymbols.artistMic)
                }
            }
            if let albumId = item.albumBrowseId, let onOpenRoute {
                Button {
                    onOpenRoute(
                        NavigationRoute(
                            browseId: albumId,
                            title: item.title,
                            artworkURL: item.artworkURL
                        )
                    )
                } label: {
                    Label(L10n.goToAlbum, systemImage: AppSymbols.albumStack)
                }
            }
        }
    }
}
