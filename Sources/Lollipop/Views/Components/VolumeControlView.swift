import SwiftUI

enum VolumeControlStyle {
    case popoverButton
    case inlinePill
}

/// Unified volume control supporting the compact bar popover and full-screen Apple Podcasts Liquid Glass pill.
struct VolumeControlView: View {
    let engine: YouTubeMusicEngine
    var style: VolumeControlStyle = .popoverButton

    @ViewState private var showPopover = false
    @ViewState private var isHovered = false
    @ViewState private var isDragging = false

    private var state: PlayerState { engine.playerState }
    private var currentVolume: Double { state.isMuted ? 0 : state.volume }
    private var volumeIcon: String {
        AppSymbols.volumeSpeaker(volume: state.volume, isMuted: state.isMuted)
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { currentVolume },
            set: { engine.setVolume($0) }
        )
    }

    var body: some View {
        switch style {
        case .popoverButton:
            Button {
                showPopover.toggle()
            } label: {
                Image(systemName: volumeIcon)
                    .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(
                PlayerIconButtonStyle(
                    size: 36,
                    foreground: .primary.opacity(0.82)
                )
            )
            .help(L10n.volume)
            .popover(isPresented: $showPopover, arrowEdge: .top) {
                HStack(spacing: 10) {
                    Button {
                        engine.toggleMute()
                    } label: {
                        Image(systemName: volumeIcon)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                    }
                    .buttonStyle(.plain)

                    Slider(value: volumeBinding, in: 0...100)
                        .frame(width: 120)
                        .tint(AppColors.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

        case .inlinePill:
            podcastsLiquidGlassVolumePill
        }
    }

    /// Faithful macOS 27 Apple Podcasts full-screen Liquid Glass volume pill:
    /// Liquid Glass capsule housing a mute speaker + subtle divider + track with
    /// horizontal capsule thumb (which morphs into clear glass when dragged) + high speaker.
    private var podcastsLiquidGlassVolumePill: some View {
        let ratio = min(max(currentVolume / 100.0, 0), 1)
        let thumbWidth: CGFloat = isDragging ? 26 : 22
        let thumbHeight: CGFloat = isDragging ? 16 : 13.5

        return HStack(spacing: 10) {
            Button {
                engine.toggleMute()
            } label: {
                Image(systemName: state.isMuted || currentVolume == 0 ? AppSymbols.speakerMuted : AppSymbols.speakerQuiet)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 16, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.volume)

            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(width: 1, height: 16)

            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let usableWidth = max(width - thumbWidth, 1)
                let thumbX = usableWidth * ratio

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.24))
                        .frame(height: 5.5)

                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: max(thumbWidth * 0.5, thumbX + thumbWidth * 0.5), height: 5.5)

                    // Horizontal capsule thumb (Apple Podcasts macOS 27 style)
                    Capsule()
                        .fill(isDragging ? Color.white.opacity(0.32) : Color.white)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    Color.white.opacity(isDragging ? 0.85 : 0.0),
                                    lineWidth: isDragging ? 1.2 : 0
                                )
                        )
                        .shadow(color: .black.opacity(isDragging ? 0.25 : 0.18), radius: isDragging ? 6 : 3, y: 1)
                        .frame(width: thumbWidth, height: thumbHeight)
                        .offset(x: thumbX)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let pct = min(max((gesture.location.x - thumbWidth * 0.5) / usableWidth, 0), 1) * 100.0
                            engine.setVolume(pct)
                        }
                        .onEnded { gesture in
                            isDragging = false
                            let pct = min(max((gesture.location.x - thumbWidth * 0.5) / usableWidth, 0), 1) * 100.0
                            engine.setVolume(pct)
                        }
                )
            }
            .frame(width: 112, height: 22)

            Button {
                engine.setVolume(100)
            } label: {
                Image(systemName: AppSymbols.speakerHigh)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.volume)
        }
        .padding(.horizontal, 13)
        .frame(height: 36)
        .liquidGlassCapsule(interactive: false)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isDragging)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
