import AppKit
import Foundation
import Observation

/// Unified async cache layer shared across Artists, Albums/Playlists, Songs, and Lyrics.
/// Ensures consistent metadata across pages, deduplicates concurrent in-flight fetches,
/// and never poisons the cache with empty/failed responses.
@MainActor
@Observable
final class MusicCacheStore {
    private struct CachedBrowseEntry {
        let page: BrowsePagePayload
        let cachedAt: Date
    }

    static let browseCacheTTL: TimeInterval = 600 // 10 minutes

    private(set) var collections: [String: CollectionDetail] = [:]
    private(set) var artists: [String: ArtistDetail] = [:]
    private(set) var tracks: [String: MusicItem] = [:]
    private(set) var lyrics: [String: LyricsData] = [:]
    private(set) var customPlaylistCovers: [String: String] = [:]
    private var browsePages: [String: CachedBrowseEntry] = [:]

    private var inFlightCollections: [String: Task<CollectionDetail?, Never>] = [:]
    private var inFlightArtists: [String: Task<ArtistDetail?, Never>] = [:]
    private var inFlightBrowsePages: [String: Task<BrowsePagePayload, Error>] = [:]

    init() {
        loadSavedCustomCovers()
    }

    // MARK: - Custom Playlist Covers & First-Song Fallback

    private static var coversDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent(AppConstants.playlistCoversDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func sanitizedCoverKey(_ browseId: String) -> String {
        let norm = normalizeCollectionBrowseId(browseId)
        return norm.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    }

    private func loadSavedCustomCovers() {
        let dir = Self.coversDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // Filename format: <sanitizedKey>__<timestamp>.jpg
        var latestByKey: [String: (date: Date, url: URL)] = [:]
        for file in files where file.pathExtension.lowercased() == AppConstants.coverFileExtension {
            let stem = file.deletingPathExtension().lastPathComponent
            let key = stem.components(separatedBy: AppConstants.coverFilenameSeparator).first ?? stem
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if let existing = latestByKey[key], existing.date >= date { continue }
            latestByKey[key] = (date, file)
        }
        for (key, entry) in latestByKey {
            customPlaylistCovers[key] = entry.url.absoluteString
        }
    }

    func hasCustomPlaylistCover(for browseId: String) -> Bool {
        customPlaylistCovers[Self.sanitizedCoverKey(browseId)] != nil
    }

    /// Resolves playlist artwork in priority order:
    /// 1) User's custom cover image, 2) First song's artwork (if remote is empty/placeholder), 3) Remote playlist artwork.
    func resolvedPlaylistArtwork(for browseId: String, remoteArtwork: String, tracks: [MusicItem]) -> String {
        let key = Self.sanitizedCoverKey(browseId)
        if let custom = customPlaylistCovers[key], !custom.isEmpty {
            return custom
        }
        if !YouTubeMusicConstants.isPlaceholderArtwork(remoteArtwork) {
            return remoteArtwork
        }
        if let firstTrackArt = tracks.first(where: { !$0.artworkURL.isEmpty })?.artworkURL {
            return firstTrackArt
        }
        return remoteArtwork
    }

    func setCustomPlaylistCover(for browseId: String, from sourceURL: URL) {
        guard let image = NSImage(contentsOf: sourceURL) else { return }
        let key = Self.sanitizedCoverKey(browseId)
        let dir = Self.coversDirectory
        let prefix = key + AppConstants.coverFilenameSeparator

        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files where f.lastPathComponent.hasPrefix(prefix) {
                try? FileManager.default.removeItem(at: f)
            }
        }

        // Resize to max 1024x1024 square-friendly JPEG
        let maxSide = AppConstants.coverMaxPixelDimension
        let origSize = image.size
        let scale = min(1.0, maxSide / max(origSize.width, origSize.height, 1))
        let targetSize = NSSize(width: round(origSize.width * scale), height: round(origSize.height * scale))

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(max(targetSize.width, 1)),
            pixelsHigh: Int(max(targetSize.height, 1)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let jpegData = rep.representation(
            using: .jpeg,
            properties: [.compressionFactor: AppConstants.coverJPEGCompression]
        ) else { return }
        let filename = "\(key)\(AppConstants.coverFilenameSeparator)\(Int(Date().timeIntervalSince1970)).\(AppConstants.coverFileExtension)"
        let dest = dir.appendingPathComponent(filename)
        if (try? jpegData.write(to: dest)) != nil {
            customPlaylistCovers[key] = dest.absoluteString
        }
    }

    func removeCustomPlaylistCover(for browseId: String) {
        let key = Self.sanitizedCoverKey(browseId)
        let dir = Self.coversDirectory
        let prefix = key + AppConstants.coverFilenameSeparator
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files where f.lastPathComponent.hasPrefix(prefix) {
                try? FileManager.default.removeItem(at: f)
            }
        }
        customPlaylistCovers.removeValue(forKey: key)
    }

    // MARK: - Normalization

    static func normalizeCollectionBrowseId(_ rawId: String) -> String {
        YouTubeMusicConstants.normalizeCollectionBrowseId(rawId)
    }

    // MARK: - Synchronous Cache Lookups

    func collection(for browseId: String) -> CollectionDetail? {
        let key = Self.normalizeCollectionBrowseId(browseId)
        guard key != YouTubeMusicConstants.BrowseID.likedMusicPlaylist else { return nil }
        return collections[key]
    }

    func artist(for browseId: String) -> ArtistDetail? {
        artists[browseId]
    }

    func track(for videoId: String) -> MusicItem? {
        tracks[videoId]
    }

    func cachedLyrics(for videoId: String) -> LyricsData? {
        lyrics[videoId]
    }

    func storeLyrics(_ data: LyricsData, for videoId: String) {
        lyrics[videoId] = data
    }

    func invalidateCollection(_ browseId: String) {
        let key = Self.normalizeCollectionBrowseId(browseId)
        collections.removeValue(forKey: key)
        inFlightCollections[key]?.cancel()
        inFlightCollections.removeValue(forKey: key)
    }

    func updateCollection(_ detail: CollectionDetail, for browseId: String) {
        let key = Self.normalizeCollectionBrowseId(browseId)
        if key != YouTubeMusicConstants.BrowseID.likedMusicPlaylist {
            collections[key] = detail
        }
        index(items: detail.tracks)
    }

    // MARK: - Deduplicated Async Loading

    func loadCollection(
        browseId: String,
        forceRefresh: Bool = false,
        fetcher: @escaping @MainActor (String) async -> CollectionDetail?
    ) async -> CollectionDetail? {
        let key = Self.normalizeCollectionBrowseId(browseId)
        if !forceRefresh,
           key != YouTubeMusicConstants.BrowseID.likedMusicPlaylist,
           let cached = collections[key],
           !cached.tracks.isEmpty {
            return cached
        }
        if !forceRefresh, let existingTask = inFlightCollections[key] {
            return await existingTask.value
        }

        let task = Task<CollectionDetail?, Never> { @MainActor in
            let fetched = await fetcher(key)
            if let detail = fetched, !detail.tracks.isEmpty {
                if key != YouTubeMusicConstants.BrowseID.likedMusicPlaylist {
                    self.collections[key] = detail
                }
                self.index(items: detail.tracks)
            }
            return fetched
        }
        inFlightCollections[key] = task
        let result = await task.value
        inFlightCollections.removeValue(forKey: key)
        return result
    }

    func loadArtist(
        browseId: String,
        forceRefresh: Bool = false,
        fetcher: @escaping @MainActor (String) async -> ArtistDetail?
    ) async -> ArtistDetail? {
        if !forceRefresh, let cached = artists[browseId], !cached.sections.isEmpty {
            return cached
        }
        if !forceRefresh, let existingTask = inFlightArtists[browseId] {
            return await existingTask.value
        }

        let task = Task<ArtistDetail?, Never> { @MainActor in
            let fetched = await fetcher(browseId)
            if let detail = fetched, !detail.sections.isEmpty {
                self.artists[browseId] = detail
                self.index(sections: detail.sections)
            }
            return fetched
        }
        inFlightArtists[browseId] = task
        let result = await task.value
        inFlightArtists.removeValue(forKey: browseId)
        return result
    }

    // MARK: - Unified Browse Page Cache (Home Chips, Explore, Moods & Genres, Remote More)

    static func browsePageKey(browseId: String, params: String?) -> String {
        if let params, !params.isEmpty {
            return "\(browseId)|\(params)"
        }
        return browseId
    }

    func browsePage(browseId: String, params: String?, allowExpired: Bool = false) -> BrowsePagePayload? {
        let key = Self.browsePageKey(browseId: browseId, params: params)
        guard let entry = browsePages[key] else { return nil }
        if !allowExpired && Date().timeIntervalSince(entry.cachedAt) > Self.browseCacheTTL {
            return nil
        }
        return entry.page
    }

    func storeBrowsePage(_ page: BrowsePagePayload, browseId: String, params: String?) {
        guard !page.sections.isEmpty else { return }
        let key = Self.browsePageKey(browseId: browseId, params: params)
        browsePages[key] = CachedBrowseEntry(page: page, cachedAt: Date())
        index(sections: page.sections)
    }

    func loadBrowsePage(
        browseId: String,
        params: String?,
        forceRefresh: Bool = false,
        fetcher: @escaping @MainActor () async throws -> BrowsePagePayload
    ) async throws -> BrowsePagePayload {
        let key = Self.browsePageKey(browseId: browseId, params: params)
        if !forceRefresh, let cached = browsePage(browseId: browseId, params: params) {
            return cached
        }
        if !forceRefresh, let existing = inFlightBrowsePages[key] {
            return try await existing.value
        }

        let task = Task<BrowsePagePayload, Error> { @MainActor in
            let fetched = try await fetcher()
            if !fetched.sections.isEmpty {
                self.storeBrowsePage(fetched, browseId: browseId, params: params)
            }
            return fetched
        }
        inFlightBrowsePages[key] = task
        do {
            let result = try await task.value
            inFlightBrowsePages.removeValue(forKey: key)
            return result
        } catch {
            inFlightBrowsePages.removeValue(forKey: key)
            throw error
        }
    }

    // MARK: - Canonical Song Indexing & Enrichment

    func index(sections: [MusicSection]) {
        for section in sections {
            index(items: section.items)
        }
    }

    func index(items: [MusicItem]) {
        for item in items {
            guard let vid = item.videoId, !vid.isEmpty else { continue }
            if let existing = tracks[vid] {
                tracks[vid] = mergeTrack(existing: existing, incoming: item)
            } else {
                tracks[vid] = item
            }
        }
    }

    /// Enriches a list of items with any canonical metadata already learned from other pages.
    func enrich(_ item: MusicItem) -> MusicItem {
        guard let vid = item.videoId, let cached = tracks[vid] else { return item }
        return mergeTrack(existing: item, incoming: cached)
    }

    private func mergeTrack(existing: MusicItem, incoming: MusicItem) -> MusicItem {
        MusicItem(
            id: existing.id,
            title: existing.title.isEmpty ? incoming.title : existing.title,
            subtitle: existing.subtitle.isEmpty ? incoming.subtitle : existing.subtitle,
            artworkURL: existing.artworkURL.isEmpty ? incoming.artworkURL : existing.artworkURL,
            kind: existing.kind,
            videoId: existing.videoId ?? incoming.videoId,
            browseId: existing.browseId ?? incoming.browseId,
            playlistId: existing.playlistId ?? incoming.playlistId,
            durationText: existing.durationText ?? incoming.durationText,
            artistName: existing.artistName ?? incoming.artistName,
            albumTitle: existing.albumTitle ?? incoming.albumTitle,
            artistBrowseId: existing.artistBrowseId ?? incoming.artistBrowseId,
            albumBrowseId: existing.albumBrowseId ?? incoming.albumBrowseId,
            setVideoId: existing.setVideoId ?? incoming.setVideoId,
            isExplicit: existing.isExplicit || incoming.isExplicit
        )
    }

    func clearAll() {
        collections.removeAll()
        artists.removeAll()
        tracks.removeAll()
        lyrics.removeAll()
        browsePages.removeAll()
        inFlightCollections.values.forEach { $0.cancel() }
        inFlightCollections.removeAll()
        inFlightArtists.values.forEach { $0.cancel() }
        inFlightArtists.removeAll()
        inFlightBrowsePages.values.forEach { $0.cancel() }
        inFlightBrowsePages.removeAll()
    }
}
