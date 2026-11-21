import Foundation

/// Centralized SF Symbol identifiers and symbol resolution helpers.
enum AppSymbols {
    // MARK: - Navigation & Sidebar
    static let home = "house"
    static let explore = "square.grid.2x2"
    static let charts = "chart.line.uptrend.xyaxis"
    static let search = "magnifyingglass"
    static let likedSongs = "heart"
    static let history = "clock"
    static let library = "square.stack"
    static let playlist = "music.note.list"

    // MARK: - Playback Transport
    static let playFill = "play.fill"
    static let pauseFill = "pause.fill"
    static let backwardFill = "backward.fill"
    static let forwardFill = "forward.fill"
    static let shuffle = "shuffle"
    static let repeatAll = "repeat"
    static let repeatOne = "repeat.1"

    // MARK: - Volume
    static let speakerQuiet = "speaker.fill"
    static let speakerMuted = "speaker.slash.fill"
    static let speakerLow = "speaker.wave.1.fill"
    static let speakerMedium = "speaker.wave.2.fill"
    static let speakerHigh = "speaker.wave.3.fill"

    static func volumeSpeaker(volume: Double, isMuted: Bool) -> String {
        if isMuted || volume == 0 {
            return speakerMuted
        } else if volume < 35 {
            return speakerLow
        } else if volume < 70 {
            return speakerMedium
        } else {
            return speakerHigh
        }
    }

    // MARK: - Actions & Chrome
    static let ellipsis = "ellipsis"
    static let plus = "plus"
    static let addToPlaylist = "text.badge.plus"
    static let heart = "heart"
    static let heartSlash = "heart.slash"
    static let trash = "trash"
    static let pencil = "pencil"
    static let link = "link"
    static let refresh = "arrow.clockwise"
    static let reset = "arrow.uturn.backward"
    static let close = "xmark"
    static let closeCircleFill = "xmark.circle.fill"
    static let chevronLeft = "chevron.left"
    static let chevronRight = "chevron.right"
    static let changeCover = "photo.badge.plus"

    // MARK: - Content & Status
    static let artistMic = "music.mic"
    static let albumStack = "square.stack"
    static let musicNote = "music.note"
    static let emptyBrowse = "music.note.house"
    static let lyricsQuote = "quote.bubble"
    static let queueList = "list.bullet"
    static let person = "person"
    static let peopleFill = "person.2.fill"
    static let artistUnavailable = "person.crop.circle.badge.exclamationmark"
    static let waveform = "waveform"
    static let waveformCircleFill = "waveform.circle.fill"
    static let fallbackAppIcon = "dot.radiowaves.up.forward"
}
