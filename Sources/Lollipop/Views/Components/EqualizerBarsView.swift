import SwiftUI

/// Animated 3-bar Apple Music-style equalizer indicator for the currently playing track row.
/// Uses GPU-composited `scaleEffect(y:anchor:)` so CoreAnimation runs off the main layout thread.
struct EqualizerBarsView: View {
    let isPlaying: Bool
    @ViewState private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(minH: 4, maxH: 13, duration: 0.45)
            bar(minH: 6, maxH: 15, duration: 0.35)
            bar(minH: 3, maxH: 11, duration: 0.52)
        }
        .frame(width: 14, height: 15, alignment: .bottom)
        .onAppear {
            if isPlaying { phase = true }
        }
        .onChange(of: isPlaying) { _, newValue in
            phase = newValue
        }
    }

    private func bar(minH: CGFloat, maxH: CGFloat, duration: Double) -> some View {
        let minScale = max(0.2, minH / maxH)
        let pausedScale = 4.0 / maxH
        return RoundedRectangle(cornerRadius: 1)
            .fill(AppColors.accent)
            .frame(width: 3, height: maxH)
            .scaleEffect(
                y: isPlaying ? (phase ? 1.0 : minScale) : pausedScale,
                anchor: .bottom
            )
            .animation(
                isPlaying
                    ? .easeInOut(duration: duration).repeatForever(autoreverses: true)
                    : AppAnimations.standard,
                value: phase
            )
    }
}
