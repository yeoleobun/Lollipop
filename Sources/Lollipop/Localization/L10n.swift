import Foundation

/// Lightweight i18n helper supporting Simplified Chinese (`zh-Hans`) and English (`en`)
/// automatically based on macOS system language (`Locale.preferredLanguages`).
enum L10n {
    private static var isChinese: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
    }

    private static func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    // MARK: - Format Helpers
    static func loading(_ item: String) -> String {
        isChinese ? "正在加载\(item)…" : "Loading \(item)…"
    }

    static func refresh(_ item: String) -> String {
        isChinese ? "刷新\(item)" : "Refresh \(item)"
    }

    static func noItemsFound(_ category: String) -> String {
        isChinese ? "暂无\(category)" : "No \(category) Found"
    }

    static func savedItemsAppearHere(_ category: String) -> String {
        isChinese ? "您收藏的\(category)将显示在这里。" : "Your saved \(category.lowercased()) will appear here."
    }

    // MARK: - Sidebar
    static var search: String { t("Search", "搜索") }
    static var home: String { t("Home", "主页") }
    static var explore: String { t("Explore", "探索") }
    static var charts: String { t("Charts", "排行榜") }
    static var yourMusic: String { t("Library", "资料库") }
    static var likedSongs: String { t("Liked Songs", "喜欢的歌曲") }
    static var history: String { t("History", "播放历史") }
    static var library: String { t("Music Library", "音乐库") }
    static var playlists: String { t("Playlists", "播放列表") }
    static var noPlaylistsYet: String { t("No playlists yet", "暂无播放列表") }
    static var signInForPlaylists: String { t("Sign in for playlists", "登录以同步播放列表") }
    static var signIn: String { t("Sign In", "登录") }
    static var account: String { t("Account", "账号") }

    // MARK: - Menu Bar Commands
    static var controlsMenu: String { t("Controls", "控制") }
    static var increaseVolume: String { t("Increase Volume", "调高音量") }
    static var decreaseVolume: String { t("Decrease Volume", "调低音量") }
    static var mute: String { t("Mute", "静音") }
    static var unmute: String { t("Unmute", "取消静音") }
    static var likeCurrentSong: String { t("Like Current Song", "喜欢当前歌曲") }
    static var toggleShuffle: String { t("Toggle Shuffle", "切换随机播放") }
    static var cycleRepeat: String { t("Cycle Repeat", "切换循环模式") }
    static var showPlayingNext: String { t("Show Playing Next", "显示待播清单") }
    static var showLyrics: String { t("Show Lyrics", "显示歌词") }
    static var showEmbeddedPlayerMenu: String { t("Show Embedded Player", "显示内置播放器") }
    static var hideEmbeddedPlayerMenu: String { t("Hide Embedded Player", "隐藏内置播放器") }

    // MARK: - Filters & Tabs
    static var topResults: String { t("Top", "最佳结果") }
    static var songs: String { t("Songs", "歌曲") }
    static var albums: String { t("Albums", "专辑") }
    static var artists: String { t("Artists", "艺人") }
    static var playingNext: String { t("Playing Next", "待播清单") }
    static var lyrics: String { t("Lyrics", "歌词") }

    // MARK: - Player & Controls
    static var notPlaying: String { t("Not Playing", "未在播放") }
    static var pickASong: String { t("Pick a song to play", "选择一首歌曲开始播放") }
    static var play: String { t("Play", "播放") }
    static var pause: String { t("Pause", "暂停") }
    static var shuffle: String { t("Shuffle", "随机播放") }
    static var previousTrack: String { t("Previous Track", "上一首") }
    static var nextTrack: String { t("Next Track", "下一首") }
    static var repeatMode: String { t("Repeat", "循环播放") }
    static var volume: String { t("Volume", "音量") }
    static var like: String { t("Like", "喜欢") }
    static var unlike: String { t("Unlike", "取消喜欢") }
    static var refresh: String { t("Refresh", "刷新") }
    static var goToArtist: String { t("Go to Artist", "前往艺人") }
    static var goToAlbum: String { t("Go to Album", "前往专辑") }
    static var loadingArtist: String { t("Loading artist…", "正在加载艺人…") }

    // MARK: - Search, Empty & Error States
    static var searchPlaceholder: String { t("Search YouTube Music", "搜索 YouTube Music") }
    static var searchDescription: String { t("Find songs, albums, artists, and playlists.", "搜索歌曲、专辑、艺人和播放列表。") }
    static var searching: String { t("Searching…", "正在搜索…") }
    static var queueEmpty: String { t("Queue Is Empty", "待播清单为空") }
    static var queueEmptyDesc: String { t("Play a song to see upcoming tracks here.", "播放歌曲后，待播曲目将显示在这里。") }
    static var lyricsUnavailable: String { t("Lyrics Unavailable", "暂无歌词") }
    static var lyricsUnavailableTrack: String { t("Lyrics are not available for this track.", "当前歌曲暂无可用歌词。") }
    static var lyricsStartPlaying: String { t("Start playing a song to view lyrics.", "播放歌曲以查看同步歌词。") }
    static var loadingLyrics: String { t("Loading lyrics…", "正在加载歌词…") }
    static var loadingQueue: String { t("Loading queue…", "正在加载待播清单…") }
    static var loadingTracks: String { t("Loading tracks…", "正在加载曲目…") }
    static var noTracksFound: String { t("No Tracks Found", "未找到曲目") }
    static var nothingLoadedYet: String { t("Nothing loaded yet", "暂无内容") }
    static var reload: String { t("Reload", "重新加载") }
    static var startingAudioEngine: String { t("Starting audio engine…", "正在启动音频引擎…") }
    static var artistUnavailable: String { t("Artist Unavailable", "未找到艺人信息") }
    static var checkConnectionTryAgain: String { t("Check your connection and try again.", "请检查网络连接后重试。") }
    static var collectionEmptySignedIn: String { t("This collection doesn't have any playable tracks.", "此列表暂无可播放曲目。") }
    static var collectionEmptySignedOut: String { t("Sign in to view your personal library and playlists.", "请登录 Google 账号以查看您的个人音乐库和播放列表。") }
    static var librarySignInPrompt: String { t("Sign in with Google to sync your YouTube Music library.", "请登录 Google 账号以同步您的 YouTube Music 音乐库。") }
    static var engineUnexpectedResponse: String { t("Unexpected response from YouTube Music engine.", "YouTube Music 引擎返回了意外响应。") }
    static var engineRequestFailed: String { t("YouTube Music request failed.", "YouTube Music 请求失败。") }

    // MARK: - Sign In, Account & Embedded Player
    static var signInWithGoogle: String { t("Sign in with Google", "使用 Google 账号登录") }
    static var signInIntroDescription: String {
        t(
            "Sign in with your Google account to sync your YouTube Music Home mixes, Liked Songs, History, and Playlists.",
            "使用 Google 账号登录 YouTube Music，以同步您的主页推荐、喜欢的歌曲、播放历史和播放列表。"
        )
    }
    static var signInSessionNotice: String {
        t(
            "Your session is stored locally in macOS WebKit's persistent container so you stay signed in. Right-click any field for Keychain AutoFill.",
            "您的登录会话仅保存在本机 macOS WebKit 安全容器中，退出应用后无需重复登录。支持右键输入框使用钥匙串自动填充。"
        )
    }
    static var autofillTip: String { t("Right-click any field → AutoFill → Passwords for Keychain", "右键输入框 → 自动填充 → 密码（支持钥匙串）") }
    static var cancel: String { t("Cancel", "取消") }
    static var done: String { t("Done", "完成") }
    static var signOut: String { t("Sign Out", "退出登录") }
    static var showEmbeddedPlayer: String { t("Show Embedded Player…", "显示内置播放器…") }
    static var syncedNotice: String { t("Your Home mixes, Liked Songs, History, and Playlists are synced.", "您的主页推荐、喜欢的歌曲、播放历史和播放列表已同步。") }
    static var connectedAudioOnlyMode: String { t("Connected • Audio-only mode", "已连接 • 仅音频模式") }
    static var defaultServiceName: String { "YouTube Music" }
    static var embeddedEngineTitle: String { t("Embedded YouTube Music Engine", "内置 YouTube Music 引擎") }
    static var embeddedEngineSubtitle: String {
        t(
            "Sign in to your Google account here. Closing this window hides the player while keeping audio playing.",
            "可在此登录 Google 账号。关闭此窗口将隐藏播放器并继续后台播放音频。"
        )
    }
    static var hidePlayer: String { t("Hide Player", "隐藏播放器") }

    // MARK: - Playlist Editing
    static var newPlaylist: String { t("New Playlist", "新建播放列表") }
    static var newPlaylistEllipsis: String { newPlaylist + AppConstants.ellipsis }
    static var editPlaylist: String { t("Edit Playlist", "编辑播放列表") }
    static var editPlaylistEllipsis: String { editPlaylist + AppConstants.ellipsis }
    static var deletePlaylist: String { t("Delete Playlist", "删除播放列表") }
    static var deletePlaylistConfirmTitle: String { t("Delete this playlist?", "确定删除此播放列表？") }
    static var deletePlaylistConfirmMsg: String { t("This will permanently delete the playlist from your YouTube Music account.", "此操作将从您的 YouTube Music 账号中永久删除该播放列表。") }
    static var addToPlaylist: String { t("Add to Playlist", "添加到播放列表") }
    static var removeFromPlaylist: String { t("Remove from Playlist", "从播放列表移除") }
    static var playlistTitle: String { t("Title", "标题") }
    static var playlistDescription: String { t("Description", "简介") }
    static var playlistPrivacy: String { t("Privacy", "隐私设置") }
    static var privacyPrivate: String { t("Private", "私享") }
    static var privacyUnlisted: String { t("Unlisted", "不公开列出") }
    static var privacyPublic: String { t("Public", "公开") }
    static var create: String { t("Create", "创建") }
    static var save: String { t("Save", "保存") }
    static var delete: String { t("Delete", "删除") }
    static var edit: String { t("Edit", "编辑") }
    static var addedToPlaylist: String { t("Added to playlist", "已添加到播放列表") }
    static var removedFromPlaylist: String { t("Removed from playlist", "已从播放列表移除") }
    static var changeCover: String { t("Change Cover…", "更换封面…") }
    static var resetCover: String { t("Reset Cover", "恢复默认封面") }
    static var copyLink: String { t("Copy Link", "拷贝链接") }
    static var cover: String { t("Cover", "封面") }
    static var chooseCover: String { t("Choose Cover…", "选取封面…") }
    static var defaultCover: String { t("First Song", "默认（首曲封面）") }
    static var ok: String { t("OK", "好") }
    static var playlistSection: String { t("Playlist", "播放列表") }
    static var playlistTitlePlaceholder: String { t("Playlist Title", "播放列表标题") }
    static var playlistDescPlaceholder: String { t("Description (Optional)", "简介（可选）") }

    // MARK: - Updates
    static var checkForUpdates: String { t("Check for Updates…", "检查更新…") }
    static var updateAvailableTitle: String { t("A New Version of Lollipop Is Available", "发现新版本 Lollipop") }
    static var upToDateTitle: String { t("You're Up to Date!", "已是最新版本") }
    static func upToDateMessage(_ version: String) -> String {
        t("Lollipop \(version) is currently the newest version available.", "当前 Lollipop \(version) 已是最新版本。")
    }
    static func updateVersionSummary(current: String, latest: String) -> String {
        t("Version \(latest) is available (you have \(current)).", "新版本 v\(latest) 已发布（当前版本 v\(current)）。")
    }
    static func updateBadge(_ version: String) -> String {
        t("Update v\(version)", "新版本 v\(version)")
    }
    static var updateCheckFailedTitle: String { t("Unable to Check for Updates", "无法检查更新") }
    static var downloadUpdate: String { t("Download Update", "前往下载") }
    static var later: String { t("Later", "稍后") }
    static var copy: String { t("Copy", "拷贝") }
    static var copied: String { t("Copied", "已拷贝") }
}
