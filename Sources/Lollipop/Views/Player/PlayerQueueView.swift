import SwiftUI

/// Up Next queue panel displayed inside the full-screen Now Playing overlay.
struct PlayerQueueView: View {
    let queue: [MusicItem]
    let currentVideoId: String
    let isPlaying: Bool
    let isRefreshing: Bool
    let onPlayTrack: (MusicItem) -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.playingNext)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: AppSymbols.refresh)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)

            if isRefreshing && queue.isEmpty {
                ProgressView(L10n.loadingQueue)
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if queue.isEmpty {
                VStack(spacing: 8) {
                    Text(L10n.queueEmpty)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(L10n.queueEmptyDesc)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(queue) { track in
                            queueRow(track)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.03),
                            .init(color: .black, location: 0.90),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private func queueRow(_ track: MusicItem) -> some View {
        let isCurrent = track.videoId != nil && track.videoId == currentVideoId

        return HStack(spacing: 12) {
            ArtworkView(urlString: track.artworkURL, size: 46, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.88))
                    .lineLimit(1)

                if !track.subtitle.isEmpty {
                    Text(track.subtitle)
                        .font(AppTypography.trackMeta)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isCurrent {
                EqualizerBarsView(isPlaying: isPlaying)
            } else if let dur = track.durationText, !dur.isEmpty {
                Text(dur)
                    .font(AppTypography.trackDuration)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCurrent ? Color.white.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPlayTrack(track)
        }
    }
}
