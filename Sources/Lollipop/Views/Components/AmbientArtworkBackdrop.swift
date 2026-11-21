import AppKit
import SwiftUI

enum AmbientBackdropStyle {
    case heroBanner(height: CGFloat = AppMetrics.heroBannerHeight, cornerRadius: CGFloat = AppMetrics.heroCornerRadius)
    case fullScreen
}

/// Unified blurred artwork backdrop shared across Artist/Collection hero banners
/// and the Full-Screen Now Playing overlay.
struct AmbientArtworkBackdrop: View {
    let artworkURL: String
    let style: AmbientBackdropStyle

    var body: some View {
        switch style {
        case .heroBanner(let height, let cornerRadius):
            if let url = URL(string: artworkURL), !artworkURL.isEmpty {
                artworkLayer(url: url)
                    .blur(radius: 60)
                    .opacity(0.22)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }

        case .fullScreen:
            ZStack {
                AppColors.fullPlayerBackground

                if let url = URL(string: artworkURL), !artworkURL.isEmpty {
                    artworkLayer(url: url)
                        .blur(radius: 90)
                        .saturation(1.35)
                        .opacity(0.62)
                }

                // Deep editorial scrim for crisp white typography readability
                LinearGradient(
                    colors: [
                        .black.opacity(0.38),
                        .black.opacity(0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func artworkLayer(url: URL) -> some View {
        GeometryReader { geo in
            if url.isFileURL, let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                }
            }
        }
    }
}
