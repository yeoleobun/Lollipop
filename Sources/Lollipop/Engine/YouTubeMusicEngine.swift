import AppKit
import Foundation
import Observation
@preconcurrency import WebKit

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: YouTubeMusicEngine?

    init(target: YouTubeMusicEngine) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }
        let type = body[YouTubeMusicConstants.Bridge.keyType] as? String ?? ""
        let payload = body[YouTubeMusicConstants.Bridge.keyPayload] as? [String: Any] ?? [:]
        MainActor.assumeIsolated {
            target?.handleBridgeMessage(type: type, payload: payload)
        }
    }
}

/// Anchor-based playback clock driven purely by discrete media events (play/pause/seek/buffering).
/// Computes current playback time locally in Swift without JS polling.
struct PlaybackClockAnchor: Equatable, Sendable {
    var anchorTime: Double = 0
    var anchorDate: Date = .distantPast
    var duration: Double = 0
    var isRunning: Bool = false

    func currentTime(at now: Date) -> Double {
        guard isRunning else { return anchorTime }
        let elapsed = max(0, now.timeIntervalSince(anchorDate))
        let raw = anchorTime + elapsed
        return duration > 0 ? min(raw, duration) : raw
    }
}

@MainActor
@Observable
final class YouTubeMusicEngine: NSObject, WKNavigationDelegate, WKUIDelegate {
    private typealias Bridge = YouTubeMusicConstants.Bridge
    private typealias PayloadKey = YouTubeMusicConstants.Bridge.PayloadKey
    private typealias BrowseID = YouTubeMusicConstants.BrowseID

    // MARK: - Embedded WebView & Auth
    let webView: WKWebView
    private let nowPlaying = NowPlayingManager()

    // MARK: - Playback & Session State
    var playerState = PlayerState()
    /// Event-driven playback clock anchor so scrubbers & synced lyrics advance locally
    /// while playing and do zero work when paused or buffering.
    var playbackClock = PlaybackClockAnchor()
    var isEngineLoaded = false
    var showEmbeddedPlayerSheet = false
    var showSignInSheet = false
    var playlistEditorMode: PlaylistEditorMode? = nil
    private(set) var playlistMutationCounter = 0
    private(set) var lastMutatedPlaylistId: String? = nil

    var isSignedIn: Bool {
        playerState.isSignedIn
    }

    // MARK: - Content State
    var homeSections: [MusicSection] = []
    var exploreSections: [MusicSection] = []
    var chartsSections: [MusicSection] = []
    var historySections: [MusicSection] = []
    var librarySections: [MusicSection] = []
    var searchSections: [MusicSection] = []
    var userPlaylists: [UserPlaylist] = []

    var queue: [MusicItem] = []
    var lyrics: LyricsData?

    var isLoadingHome = false
    var isLoadingExplore = false
    var isLoadingCharts = false
    var isLoadingHistory = false
    var isLoadingLibrary = false
    var isLoadingSearch = false
    var isLoadingDetail = false
    var errorMessage: String?

    private var lastFetchedVideoId: String = ""
    private var lastSignedInState: Bool = false

    // Unified async cache layer shared across Artists, Albums/Playlists, Songs, and Lyrics
    let cache = MusicCacheStore()

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let script = WKUserScript(
            source: BridgeScript.source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        self.webView = WKWebView(frame: AppMetrics.hiddenWebViewFrame, configuration: config)
        super.init()

        self.webView.customUserAgent = AppConstants.safariUserAgent
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.allowsBackForwardNavigationGestures = false

        let proxy = WeakScriptMessageHandler(target: self)
        config.userContentController.add(proxy, name: Bridge.handlerName)

        wireNowPlaying()
        loadYouTubeMusic()
    }

    private func wireNowPlaying() {
        nowPlaying.onPlay = { [weak self] in self?.play() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onTogglePlayPause = { [weak self] in self?.togglePlayPause() }
        nowPlaying.onNext = { [weak self] in self?.nextTrack() }
        nowPlaying.onPrevious = { [weak self] in self?.previousTrack() }
        nowPlaying.onSeek = { [weak self] seconds in self?.seek(to: seconds) }
    }

    func loadYouTubeMusic() {
        guard let url = URL(string: YouTubeMusicConstants.origin) else { return }
        webView.load(URLRequest(url: url))
    }

    func openSignIn() {
        showSignInSheet = true
    }

    func presentCreatePlaylist(initialVideoId: String? = nil) {
        playlistEditorMode = .create(initialVideoId: initialVideoId)
    }

    func presentEditPlaylist(playlistId: String, title: String, description: String) {
        playlistEditorMode = .edit(playlistId: playlistId, title: title, description: description)
    }

    func handleGoogleSignInCompleted() {
        showSignInSheet = false
        loadYouTubeMusic()
    }

    func signOut() async {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let existing = await store.allCookies()
        for cookie in existing {
            if AppConstants.authCookieDomains.contains(where: { cookie.domain.contains($0) }) {
                await store.deleteCookie(cookie)
            }
        }
        playerState.accountName = ""
        playerState.accountEmail = ""
        playerState.accountAvatarURL = ""
        userPlaylists = []
        cache.clearAll()
        loadYouTubeMusic()
    }

    // MARK: - WKNavigationDelegate & WKUIDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let host = webView.url?.host, host.contains(YouTubeMusicConstants.host) {
            self.isEngineLoaded = true
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Keep OAuth / popups inside the same webview
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // MARK: - Bridge Message Handling

    func handleBridgeMessage(type: String, payload: [String: Any]) {
        switch type {
        case Bridge.eventPlayerState:
            updatePlayerState(from: payload)
        case Bridge.eventEngineReady:
            isEngineLoaded = true
            let signedIn = payload[PayloadKey.isSignedIn] as? Bool ?? false
            lastSignedInState = signedIn
            Task {
                await refreshHome()
                if signedIn {
                    await refreshAccountProfile()
                    await refreshUserPlaylists()
                }
            }
        default:
            break
        }
    }

    private func updatePlayerState(from dict: [String: Any]) {
        var next = playerState
        next.videoId = dict[PayloadKey.videoId] as? String ?? ""
        next.title = dict[PayloadKey.title] as? String ?? ""
        next.artist = dict[PayloadKey.artist] as? String ?? ""
        next.album = dict[PayloadKey.album] as? String ?? ""
        next.artworkURL = dict[PayloadKey.artworkURL] as? String ?? ""
        next.isPlaying = dict[PayloadKey.isPlaying] as? Bool ?? false
        let isBuffering = dict[PayloadKey.isBuffering] as? Bool ?? false
        let incomingTime = dict[PayloadKey.currentTime] as? Double ?? 0
        next.duration = dict[PayloadKey.duration] as? Double ?? 0
        next.volume = dict[PayloadKey.volume] as? Double ?? 100
        next.isMuted = dict[PayloadKey.isMuted] as? Bool ?? false
        next.isShuffled = dict[PayloadKey.isShuffled] as? Bool ?? false
        next.isSignedIn = dict[PayloadKey.isSignedIn] as? Bool ?? false
        next.isReady = dict[PayloadKey.isReady] as? Bool ?? false

        let domArtistId = dict[PayloadKey.artistBrowseId] as? String ?? ""
        let domAlbumId = dict[PayloadKey.albumBrowseId] as? String ?? ""
        if !domArtistId.isEmpty {
            next.artistBrowseId = domArtistId
        } else if next.videoId != playerState.videoId {
            next.artistBrowseId = ""
        }
        if !domAlbumId.isEmpty {
            next.albumBrowseId = domAlbumId
        } else if next.videoId != playerState.videoId {
            next.albumBrowseId = ""
        }

        if let rep = dict[PayloadKey.repeatMode] as? String, let mode = RepeatMode(rawValue: rep) {
            next.repeatMode = mode
        }
        if let ls = dict[PayloadKey.likeStatus] as? String, let status = LikeStatus(rawValue: ls) {
            next.likeStatus = status
        }

        let nextClock = PlaybackClockAnchor(
            anchorTime: incomingTime,
            anchorDate: Date(),
            duration: next.duration,
            isRunning: next.isPlaying && !isBuffering
        )
        if nextClock.isRunning != playbackClock.isRunning
            || nextClock.duration != playbackClock.duration
            || abs(nextClock.anchorTime - playbackClock.currentTime(at: nextClock.anchorDate)) >= 0.45
            || next.videoId != playerState.videoId {
            playbackClock = nextClock
        }

        if next != playerState {
            playerState = next
            nowPlaying.update(with: next)
        }

        // Detect sign-in transition
        if next.isSignedIn != lastSignedInState {
            lastSignedInState = next.isSignedIn
            if next.isSignedIn {
                Task {
                    await refreshHome()
                    await refreshAccountProfile()
                    await refreshUserPlaylists()
                }
            } else {
                playerState.accountName = ""
                playerState.accountEmail = ""
                playerState.accountAvatarURL = ""
                userPlaylists = []
            }
        }

        // Refresh Up Next & Lyrics when track changes
        if !next.videoId.isEmpty && next.videoId != lastFetchedVideoId {
            lastFetchedVideoId = next.videoId
            Task {
                await refreshQueueAndLyrics(videoId: next.videoId)
            }
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        evalVoid(Bridge.togglePlay)
    }

    func play() {
        evalVoid(Bridge.play)
    }

    func pause() {
        evalVoid(Bridge.pause)
    }

    func nextTrack() {
        evalVoid(Bridge.next)
    }

    func previousTrack() {
        evalVoid(Bridge.previous)
    }

    func seek(to seconds: Double) {
        playbackClock = PlaybackClockAnchor(
            anchorTime: seconds,
            anchorDate: Date(),
            duration: playerState.duration,
            isRunning: playbackClock.isRunning
        )
        evalVoid(Bridge.seek(seconds))
    }

    func setVolume(_ volume: Double) {
        let clamped = min(max(volume, 0), 100)
        playerState.volume = clamped
        if clamped > 0 { playerState.isMuted = false }
        evalVoid(Bridge.setVolume(clamped))
    }

    func adjustVolume(by delta: Double) {
        setVolume(playerState.volume + delta)
    }

    func toggleMute() {
        evalVoid(Bridge.toggleMute)
    }

    func toggleLike() {
        evalVoid(Bridge.toggleLike)
    }

    func likeTrack(videoId: String) async -> Bool {
        struct OkPayload: Decodable { let ok: Bool }
        do {
            let result: OkPayload = try await callAsyncBridge(
                Bridge.likeTrack(videoIdJSON: jsString(videoId))
            )
            return result.ok
        } catch {
            return false
        }
    }

    func toggleShuffle() {
        evalVoid(Bridge.toggleShuffle)
    }

    func cycleRepeat() {
        evalVoid(Bridge.cycleRepeat)
    }

    func play(videoId: String, playlistId: String? = nil) {
        let vidJSON = jsString(videoId)
        let plJSON = playlistId.map { jsString($0) } ?? "null"
        evalVoid(Bridge.playVideo(videoIdJSON: vidJSON, playlistIdJSON: plJSON))
    }

    func play(item: MusicItem) {
        if let vid = item.videoId {
            play(videoId: vid, playlistId: item.playlistId)
        } else if let pl = item.playlistId {
            play(videoId: "", playlistId: pl)
        }
    }

    // MARK: - Content Fetching

    func refreshHome() async {
        await fetchBrowseSections(
            browseId: BrowseID.home,
            setLoading: { isLoadingHome = $0 },
            applySections: { homeSections = $0 }
        )
    }

    func refreshExplore() async {
        await fetchBrowseSections(
            browseId: BrowseID.explore,
            setLoading: { isLoadingExplore = $0 },
            applySections: { exploreSections = $0 }
        )
    }

    func refreshCharts() async {
        await fetchBrowseSections(
            browseId: BrowseID.charts,
            setLoading: { isLoadingCharts = $0 },
            applySections: { chartsSections = $0 }
        )
    }

    func refreshHistory() async {
        await fetchBrowseSections(
            browseId: BrowseID.history,
            setLoading: { isLoadingHistory = $0 },
            applySections: { historySections = $0 }
        )
    }

    func loadLibrary(browseId: String) async {
        await fetchBrowseSections(
            browseId: browseId,
            setLoading: { isLoadingLibrary = $0 },
            applySections: { librarySections = $0 }
        )
    }

    private func fetchBrowseSections(
        browseId: String,
        setLoading: (Bool) -> Void,
        applySections: ([MusicSection]) -> Void
    ) async {
        setLoading(true)
        defer { setLoading(false) }
        do {
            let sections: [MusicSection] = try await callAsyncBridge(
                Bridge.fetchBrowse(browseIdJSON: jsString(browseId))
            )
            applySections(sections)
            cache.index(sections: sections)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAccountProfile() async {
        struct ProfilePayload: Decodable {
            let name: String
            let email: String
            let avatarURL: String
        }
        do {
            let profile: ProfilePayload = try await callAsyncBridge(Bridge.fetchAccountProfile)
            playerState.accountName = profile.name
            playerState.accountEmail = profile.email
            playerState.accountAvatarURL = profile.avatarURL
        } catch {
            // Non-fatal
        }
    }

    func refreshUserPlaylists() async {
        do {
            userPlaylists = try await callAsyncBridge(Bridge.fetchUserPlaylists)
        } catch {
            // Non-fatal if signed out
        }
    }

    // MARK: - Playlist Editing (Create / Rename / Add / Remove / Delete)

    func createPlaylist(
        title: String,
        description: String = "",
        privacyStatus: String = YouTubeMusicConstants.defaultPrivacyStatus,
        initialVideoId: String? = nil
    ) async -> String? {
        struct CreatePayload: Decodable {
            let playlistId: String
            let browseId: String
        }
        let videoIdsJS = initialVideoId.map { "[\(jsString($0))]" } ?? "[]"
        do {
            let result: CreatePayload = try await callAsyncBridge(
                Bridge.createPlaylist(
                    titleJSON: jsString(title),
                    descriptionJSON: jsString(description),
                    privacyJSON: jsString(privacyStatus),
                    videoIdsJS: videoIdsJS
                )
            )
            guard !result.browseId.isEmpty else { return nil }
            await refreshUserPlaylists()
            return result.browseId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func editPlaylistMetadata(
        playlistId: String,
        title: String,
        description: String,
        privacyStatus: String? = nil
    ) async -> Bool {
        struct OkPayload: Decodable { let ok: Bool }
        let privacyJS = privacyStatus.map { jsString($0) } ?? "null"
        do {
            let result: OkPayload = try await callAsyncBridge(
                Bridge.editPlaylistMetadata(
                    playlistIdJSON: jsString(playlistId),
                    titleJSON: jsString(title),
                    descriptionJSON: jsString(description),
                    privacyJSON: privacyJS
                )
            )
            if result.ok {
                cache.invalidateCollection(playlistId)
                lastMutatedPlaylistId = playlistId
                playlistMutationCounter += 1
                await refreshUserPlaylists()
            }
            return result.ok
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addTrackToPlaylist(playlistId: String, videoId: String) async -> Bool {
        struct OkPayload: Decodable { let ok: Bool }
        do {
            let result: OkPayload = try await callAsyncBridge(
                Bridge.addTrackToPlaylist(
                    playlistIdJSON: jsString(playlistId),
                    videoIdJSON: jsString(videoId)
                )
            )
            if result.ok {
                cache.invalidateCollection(playlistId)
                lastMutatedPlaylistId = playlistId
                playlistMutationCounter += 1
            }
            return result.ok
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeTrackFromPlaylist(playlistId: String, videoId: String, setVideoId: String) async -> Bool {
        struct OkPayload: Decodable { let ok: Bool }
        do {
            let result: OkPayload = try await callAsyncBridge(
                Bridge.removeTrackFromPlaylist(
                    playlistIdJSON: jsString(playlistId),
                    videoIdJSON: jsString(videoId),
                    setVideoIdJSON: jsString(setVideoId)
                )
            )
            if result.ok {
                cache.invalidateCollection(playlistId)
                lastMutatedPlaylistId = playlistId
                playlistMutationCounter += 1
            }
            return result.ok
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deletePlaylist(playlistId: String) async -> Bool {
        struct OkPayload: Decodable { let ok: Bool }
        do {
            let result: OkPayload = try await callAsyncBridge(
                Bridge.deletePlaylist(playlistIdJSON: jsString(playlistId))
            )
            if result.ok {
                let normalized = MusicCacheStore.normalizeCollectionBrowseId(playlistId)
                cache.invalidateCollection(normalized)
                userPlaylists.removeAll { $0.id == normalized || $0.id == playlistId }
            }
            return result.ok
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func search(query: String, filter: SearchFilter) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchSections = []
            return
        }
        isLoadingSearch = true
        defer { isLoadingSearch = false }
        do {
            let paramsJS = filter.innertubeParams.map { jsString($0) } ?? "null"
            let sections: [MusicSection] = try await callAsyncBridge(
                Bridge.fetchSearch(queryJSON: jsString(trimmed), paramsJSON: paramsJS)
            )
            searchSections = sections
            cache.index(sections: sections)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchArtist(browseId: String, forceRefresh: Bool = false) async -> ArtistDetail? {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        return await cache.loadArtist(browseId: browseId, forceRefresh: forceRefresh) { [weak self] key in
            guard let self else { return nil }
            do {
                let detail: ArtistDetail = try await self.callAsyncBridge(
                    Bridge.fetchArtist(browseIdJSON: self.jsString(key))
                )
                self.errorMessage = nil
                return detail
            } catch {
                self.errorMessage = error.localizedDescription
                return nil
            }
        }
    }

    func fetchCollection(browseId: String, forceRefresh: Bool = false) async -> CollectionDetail? {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        return await cache.loadCollection(browseId: browseId, forceRefresh: forceRefresh) { [weak self] key in
            guard let self else { return nil }
            do {
                let detail: CollectionDetail = try await self.callAsyncBridge(
                    Bridge.fetchCollection(browseIdJSON: self.jsString(key))
                )
                self.errorMessage = nil
                return detail
            } catch {
                self.errorMessage = error.localizedDescription
                return nil
            }
        }
    }

    func refreshQueueAndLyrics(videoId: String) async {
        struct TimedLinePayload: Decodable {
            let text: String
            let startTime: Double?
        }
        struct LyricsPayload: Decodable {
            let lines: [String]
            let timedLines: [TimedLinePayload]?
            let source: String
        }
        struct QueueLyricsResponse: Decodable {
            let queue: [MusicItem]
            let lyrics: LyricsPayload?
        }

        // Clear stale lyrics immediately when switching songs, or restore from shared cache
        if let cachedLyrics = cache.cachedLyrics(for: videoId) {
            lyrics = cachedLyrics
        } else if lastFetchedVideoId == videoId {
            lyrics = nil
        }

        do {
            let response: QueueLyricsResponse = try await callAsyncBridge(
                Bridge.fetchQueueAndLyrics(videoIdJSON: jsString(videoId))
            )
            queue = response.queue
            cache.index(items: response.queue)

            // Enrich active track's artistBrowseId & albumBrowseId from queue + shared track cache
            let active = response.queue.first(where: { $0.videoId == videoId }).map { cache.enrich($0) }
                ?? cache.track(for: videoId)
            if let active {
                if playerState.artistBrowseId.isEmpty, let aid = active.artistBrowseId {
                    playerState.artistBrowseId = aid
                }
                if playerState.albumBrowseId.isEmpty, let alid = active.albumBrowseId {
                    playerState.albumBrowseId = alid
                }
            }

            if let l = response.lyrics {
                if let timed = l.timedLines, timed.contains(where: { $0.startTime != nil }) {
                    let synced = LyricsData(
                        lines: timed.enumerated().map { idx, item in
                            LyricLine(id: idx, text: item.text, startTime: item.startTime)
                        },
                        source: l.source
                    )
                    lyrics = synced
                    cache.storeLyrics(synced, for: videoId)
                    return
                } else {
                    lyrics = LyricsData(
                        lines: l.lines.enumerated().map { idx, text in
                            LyricLine(id: idx, text: text, startTime: nil)
                        },
                        source: l.source
                    )
                }
            } else {
                lyrics = nil
            }
        } catch {
            // Keep existing queue if fetch fails
        }

        // Upgrade plain or missing lyrics to real-time synced LRC lyrics via LRCLIB
        if cache.cachedLyrics(for: videoId)?.isSynced == true { return }
        let title = playerState.title
        let artist = playerState.artist
        let duration = playerState.duration
        if !title.isEmpty,
           let synced = await SyncedLyricsProvider.fetchSyncedLyrics(
               title: title,
               artist: artist,
               duration: duration
           ),
           playerState.videoId == videoId {
            lyrics = synced
            cache.storeLyrics(synced, for: videoId)
        } else if let current = lyrics {
            cache.storeLyrics(current, for: videoId)
        }
    }

    // MARK: - JS Execution Helpers

    private func evalVoid(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func callAsyncBridge<T: Decodable>(_ functionBody: String) async throws -> T {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let result = try await webView.callAsyncJavaScript(
                    functionBody,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8) else {
                    throw NSError(
                        domain: Bridge.errorDomain,
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: L10n.engineUnexpectedResponse]
                    )
                }
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                lastError = error
                if attempt == 0 {
                    // Retry once after a brief pause in case a WebView navigation interrupted JS
                    try? await Task.sleep(for: .milliseconds(AppConstants.bridgeRetryDelayMilliseconds))
                }
            }
        }
        throw lastError ?? NSError(
            domain: Bridge.errorDomain,
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: L10n.engineRequestFailed]
        )
    }

    private func jsString(_ value: String) -> String {
        if let data = try? JSONEncoder().encode(value),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\"\""
    }
}
