import SwiftUI

/// Native macOS SF Symbol waveform indicator for the currently playing track row.
struct EqualizerBarsView: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.accent)
            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            .frame(width: 16, height: 16)
    }
}
