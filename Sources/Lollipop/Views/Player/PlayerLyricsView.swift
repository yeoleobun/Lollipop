import SwiftUI

/// Synced and plain lyrics panel displayed inside the full-screen Now Playing overlay.
/// Renders in an Apple Music-inspired wheel (滚轮) viewport: the active line stays
/// centered vertically while surrounding lines smoothly fade in and out without
/// overflowing to the window edges.
struct PlayerLyricsView: View {
    let lyrics: LyricsData?
    let currentTime: Double
    let hasTrack: Bool
    let isRefreshing: Bool
    let onSeek: (Double) -> Void

    var body: some View {
        Group {
            if isRefreshing && lyrics == nil {
                ProgressView(L10n.loadingLyrics)
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let lyrics, !lyrics.lines.isEmpty {
                GeometryReader { geo in
                    let wheelHeight = min(max(geo.size.height * 0.84, 260), 520)
                    let edgeSpacer = max(40, wheelHeight * 0.5 - 22)
                    let activeIdx = activeLineIndex(for: lyrics, at: currentTime)
                    let rankMap = nonEmptyRankMap(for: lyrics.lines)
                    let activeRank = activeIdx.flatMap { rankMap[$0] } ?? 0

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: lyrics.isSynced ? 22 : 16) {
                                Spacer().frame(height: lyrics.isSynced ? edgeSpacer : 32)

                                ForEach(lyrics.lines) { line in
                                    if line.text.trimmingCharacters(in: .whitespaces).isEmpty {
                                        Spacer().frame(height: 8)
                                    } else {
                                        let rank = rankMap[line.id] ?? 0
                                        let distance = lyrics.isSynced ? abs(rank - activeRank) : 0
                                        FullLyricLineRow(
                                            line: line,
                                            isSynced: lyrics.isSynced,
                                            isActive: lyrics.isSynced && activeIdx == line.id,
                                            distance: distance,
                                            onSeek: onSeek
                                        )
                                        .id(line.id)
                                    }
                                }

                                if !lyrics.source.isEmpty {
                                    Text(lyrics.source)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .padding(.top, 16)
                                }

                                Spacer().frame(height: lyrics.isSynced ? edgeSpacer : 48)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 12)
                        }
                        .frame(height: wheelHeight)
                        .mask(wheelFadeMask(isSynced: lyrics.isSynced))
                        .onAppear {
                            scrollToActive(proxy: proxy, activeIdx: activeIdx, lyrics: lyrics, animated: false)
                        }
                        .onChange(of: activeIdx) { _, newIdx in
                            scrollToActive(proxy: proxy, activeIdx: newIdx, lyrics: lyrics, animated: true)
                        }
                        .onChange(of: lyrics.lines.count) { _, _ in
                            scrollToActive(proxy: proxy, activeIdx: activeIdx, lyrics: lyrics, animated: false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            } else {
                VStack(spacing: 8) {
                    Text(L10n.lyricsUnavailable)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(hasTrack ? L10n.lyricsUnavailableTrack : L10n.lyricsStartPlaying)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func wheelFadeMask(isSynced: Bool) -> some View {
        LinearGradient(
            stops: isSynced
                ? [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.32), location: 0.16),
                    .init(color: .black, location: 0.34),
                    .init(color: .black, location: 0.66),
                    .init(color: .black.opacity(0.32), location: 0.84),
                    .init(color: .clear, location: 1.0),
                ]
                : [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1.0),
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func scrollToActive(
        proxy: ScrollViewProxy,
        activeIdx: Int?,
        lyrics: LyricsData,
        animated: Bool
    ) {
        guard lyrics.isSynced else { return }
        let targetId = activeIdx ?? lyrics.lines.first(where: {
            !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
        })?.id
        guard let targetId else { return }
        if animated {
            withAnimation(AppAnimations.lyricsScroll) {
                proxy.scrollTo(targetId, anchor: .center)
            }
        } else {
            DispatchQueue.main.async {
                proxy.scrollTo(targetId, anchor: .center)
            }
        }
    }

    private func nonEmptyRankMap(for lines: [LyricLine]) -> [Int: Int] {
        var map: [Int: Int] = [:]
        var rank = 0
        for line in lines where !line.text.trimmingCharacters(in: .whitespaces).isEmpty {
            map[line.id] = rank
            rank += 1
        }
        return map
    }

    private func activeLineIndex(for lyrics: LyricsData, at currentTime: Double) -> Int? {
        guard lyrics.isSynced else { return nil }
        let target = currentTime + AppConstants.lyricsSyncLeadTime
        var active: Int?
        for line in lyrics.lines {
            if let start = line.startTime, start <= target {
                active = line.id
            } else if let start = line.startTime, start > target {
                break
            }
        }
        return active ?? lyrics.lines.first(where: {
            !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
        })?.id
    }
}

private struct FullLyricLineRow: View {
    let line: LyricLine
    let isSynced: Bool
    let isActive: Bool
    let distance: Int
    let onSeek: (Double) -> Void

    @ViewState private var isHovered = false

    var body: some View {
        Text(line.text)
            .font(.system(size: isSynced ? 25 : 22, weight: .bold))
            .foregroundStyle(.white)
            .opacity(lineOpacity)
            .scaleEffect(lineScale, anchor: .leading)
            .blur(radius: lineBlur)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .animation(AppAnimations.lyricsActiveRow, value: isActive)
            .animation(AppAnimations.lyricsActiveRow, value: distance)
            .animation(AppAnimations.fastHover, value: isHovered)
            .onHover { isHovered = $0 }
            .onTapGesture {
                if let start = line.startTime {
                    onSeek(start)
                }
            }
    }

    private var lineOpacity: Double {
        if !isSynced { return 0.88 }
        if isActive { return 1.0 }
        if isHovered { return 0.85 }
        switch distance {
        case 1: return 0.52
        case 2: return 0.28
        case 3: return 0.13
        default: return 0.04
        }
    }

    private var lineScale: CGFloat {
        if !isSynced { return 1.0 }
        if isActive { return 1.06 }
        if isHovered { return 0.99 }
        switch distance {
        case 1: return 0.96
        case 2: return 0.92
        case 3: return 0.89
        default: return 0.86
        }
    }

    private var lineBlur: CGFloat {
        if !isSynced || isActive || isHovered { return 0 }
        switch distance {
        case 1: return 0.35
        case 2: return 0.95
        case 3: return 1.5
        default: return 2.0
        }
    }
}
