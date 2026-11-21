import SwiftUI

/// Animated equalizer indicator like Apple Music's now-playing row animation.
struct EqualizerBarsView: View {
    let isPlaying: Bool
    @ViewState private var phase: Bool = false

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
        RoundedRectangle(cornerRadius: 1)
            .fill(AppColors.accent)
            .frame(width: 3, height: isPlaying ? (phase ? maxH : minH) : 4)
            .animation(
                isPlaying
                    ? .easeInOut(duration: duration).repeatForever(autoreverses: true)
                    : AppAnimations.standard,
                value: phase
            )
    }
}
