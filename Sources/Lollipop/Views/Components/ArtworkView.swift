import AppKit
import SwiftUI

/// Two-tier artwork image cache (in-memory `NSCache` + persistent disk `URLCache`)
/// with in-flight request deduplication for zero-flicker native macOS scrolling & tab switching.
@MainActor
final class ArtworkImageCache {
    static let shared = ArtworkImageCache()

    private let memoryCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 400
        cache.totalCostLimit = 80 * 1024 * 1024 // 80 MB
        return cache
    }()

    private let session: URLSession = {
        let cacheDir = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("LollipopArtworkCache", isDirectory: true)
        let urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: cacheDir
        )
        let config = URLSessionConfiguration.default
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 8
        return URLSession(configuration: config)
    }()

    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    func cachedImage(for urlString: String) -> NSImage? {
        guard !urlString.isEmpty else { return nil }
        return memoryCache.object(forKey: urlString as NSString)
    }

    func loadImage(for urlString: String) async -> NSImage? {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
        if let existing = memoryCache.object(forKey: urlString as NSString) {
            return existing
        }

        if url.isFileURL {
            let fileURL = url
            let loaded = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: fileURL)
            }.value
            if let loaded {
                store(loaded, forKey: urlString)
            }
            return loaded
        }

        if let task = inFlight[urlString] {
            return await task.value
        }

        let session = self.session
        let task = Task<NSImage?, Never> {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                return await Task.detached(priority: .userInitiated) {
                    NSImage(data: data)
                }.value
            } catch {
                return nil
            }
        }
        inFlight[urlString] = task
        let image = await task.value
        inFlight.removeValue(forKey: urlString)
        if let image {
            store(image, forKey: urlString)
        }
        return image
    }

    private func store(_ image: NSImage, forKey key: String) {
        let rep = image.representations.first
        let pixelsW = rep?.pixelsWide ?? Int(image.size.width)
        let pixelsH = rep?.pixelsHigh ?? Int(image.size.height)
        let cost = max(1, pixelsW * pixelsH * 4)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

struct ArtworkView: View {
    let urlString: String
    var size: CGFloat
    var cornerRadius: CGFloat = 10
    var isCircular: Bool = false

    @ViewState private var loadedImage: NSImage? = nil
    @ViewState private var loadedURLString: String = ""

    private var displayedImage: NSImage? {
        if let cached = ArtworkImageCache.shared.cachedImage(for: urlString) {
            return cached
        }
        if loadedURLString == urlString {
            return loadedImage
        }
        return nil
    }

    var body: some View {
        Group {
            if let nsImage = displayedImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
        .task(id: urlString) {
            guard !urlString.isEmpty else {
                loadedImage = nil
                loadedURLString = ""
                return
            }
            if let cached = ArtworkImageCache.shared.cachedImage(for: urlString) {
                loadedImage = cached
                loadedURLString = urlString
                return
            }
            let fetched = await ArtworkImageCache.shared.loadImage(for: urlString)
            guard !Task.isCancelled else { return }
            withAnimation(AppAnimations.fastHover) {
                loadedImage = fetched
                loadedURLString = urlString
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
