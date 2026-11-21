import AppKit
import SwiftUI

struct ArtworkView: View {
    let urlString: String
    var size: CGFloat
    var cornerRadius: CGFloat = 10
    var isCircular: Bool = false

    var body: some View {
        Group {
            if let url = URL(string: urlString), !urlString.isEmpty {
                if url.isFileURL, let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    AsyncImage(url: url, transaction: Transaction(animation: AppAnimations.standard)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            if isCircular {
                Circle().strokeBorder(AppColors.artworkBorder, lineWidth: 0.5)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppColors.artworkBorder, lineWidth: 0.5)
            }
        }
    }

    private var shape: AnyShape {
        if isCircular {
            AnyShape(Circle())
        } else {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.artworkPlaceholderTop,
                    AppColors.artworkPlaceholderBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: AppSymbols.musicNote)
                .font(.system(size: max(14, size * 0.34), weight: .medium))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}
