import SwiftUI

struct EmbeddedPlayerSheet: View {
    let engine: YouTubeMusicEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: AppSymbols.waveformCircleFill)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.embeddedEngineTitle)
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.embeddedEngineSubtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(L10n.reload) {
                    engine.loadYouTubeMusic()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(L10n.hidePlayer) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            SharedWebViewHost(
                webView: engine.webView,
                isActiveHost: engine.showEmbeddedPlayerSheet
            )
        }
        .frame(
            minWidth: AppMetrics.embeddedSheetMinWidth,
            minHeight: AppMetrics.embeddedSheetMinHeight
        )
    }
}
