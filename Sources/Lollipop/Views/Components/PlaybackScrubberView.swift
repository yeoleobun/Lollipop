import SwiftUI

enum PlaybackScrubberStyle {
    case compactBar
    case fullScreen
}

/// Unified interactive drag/hover scrubber shared by NowPlayingBar and FullScreenPlayerView.
struct PlaybackScrubberView: View {
    let value: Double
    let total: Double
    var style: PlaybackScrubberStyle = .compactBar
    let onEditingChanged: (Bool, Double) -> Void

    @ViewState private var isHovered = false
    @ViewState private var isDragging = false

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    private var isEmphasized: Bool {
        isHovered || isDragging
    }

    private var barHeight: CGFloat {
        switch style {
        case .compactBar:
            return isEmphasized ? 5 : 3.5
        case .fullScreen:
            return isEmphasized ? 7 : 5
        }
    }

    private var containerHeight: CGFloat {
        switch style {
        case .compactBar: return 10
        case .fullScreen: return 16
        }
    }

    private var trackColor: Color {
        switch style {
        case .compactBar: return Color.primary.opacity(0.14)
        case .fullScreen: return .white.opacity(0.24)
        }
    }

    private var fillColor: Color {
        switch style {
        case .compactBar:
            return isEmphasized ? AppColors.accent : Color.primary.opacity(0.65)
        case .fullScreen:
            return .white.opacity(0.92)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: barHeight)

                Capsule()
                    .fill(fillColor)
                    .frame(width: width * progress, height: barHeight)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let ratio = min(max(gesture.location.x / width, 0), 1)
                        onEditingChanged(true, ratio * total)
                    }
                    .onEnded { gesture in
                        isDragging = false
                        let ratio = min(max(gesture.location.x / width, 0), 1)
                        onEditingChanged(false, ratio * total)
                    }
            )
            .onHover { hovering in
                withAnimation(AppAnimations.scrubberHover) {
                    isHovered = hovering
                }
            }
        }
        .frame(height: containerHeight)
    }
}
