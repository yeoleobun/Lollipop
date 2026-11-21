import SwiftUI

/// Compact "E" explicit content badge.
struct ExplicitBadgeView: View {
    var body: some View {
        Text(AppConstants.explicitBadgeLabel)
            .font(AppTypography.explicitBadge)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(AppColors.explicitBadgeFill, in: RoundedRectangle(cornerRadius: 2))
    }
}

/// Independent inline metadata link with its own hover underline.
struct HoverLinkText: View {
    let text: String
    var fontSize: CGFloat = 12
    let action: () -> Void

    @ViewState private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: fontSize))
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                .underline(isHovered)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Shared inline "Artist · Album" clickable metadata row used by TrackRowView,
/// MediaCardView, and SearchView.
struct TrackMetadataLinksView: View {
    let item: MusicItem
    var showAlbum: Bool = true
    var fontSize: CGFloat = 12
    var onOpenRoute: ((NavigationRoute) -> Void)?

    private var artistLabel: String? {
        item.artistName ?? (!item.subtitle.isEmpty ? item.subtitle : nil)
    }

    private var hasInteractiveLinks: Bool {
        guard onOpenRoute != nil else { return false }
        let hasArtist = item.artistBrowseId != nil
        let hasAlbum = showAlbum && item.albumBrowseId != nil && !(item.albumTitle?.isEmpty ?? true)
        return hasArtist || hasAlbum
    }

    var body: some View {
        if hasInteractiveLinks, let onOpenRoute {
            HStack(spacing: 4) {
                if let artistLabel {
                    if let artistId = item.artistBrowseId {
                        HoverLinkText(text: artistLabel, fontSize: fontSize) {
                            onOpenRoute(
                                NavigationRoute(browseId: artistId, title: artistLabel, artworkURL: item.artworkURL)
                            )
                        }
                    } else {
                        Text(artistLabel)
                            .font(.system(size: fontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if showAlbum,
                   let albumLabel = item.albumTitle,
                   !albumLabel.isEmpty,
                   let albumId = item.albumBrowseId {
                    if artistLabel != nil {
                        Text(AppConstants.metadataBullet)
                            .font(.system(size: fontSize))
                            .foregroundStyle(.tertiary)
                    }
                    HoverLinkText(text: albumLabel, fontSize: fontSize) {
                        onOpenRoute(
                            NavigationRoute(browseId: albumId, title: albumLabel, artworkURL: item.artworkURL)
                        )
                    }
                }
            }
        } else if !item.subtitle.isEmpty {
            Text(item.subtitle)
                .font(.system(size: fontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
