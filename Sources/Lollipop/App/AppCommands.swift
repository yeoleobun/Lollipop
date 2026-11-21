import SwiftUI

struct AppCommands: Commands {
    let engine: YouTubeMusicEngine
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab

    var body: some Commands {
        CommandMenu(L10n.controlsMenu) {
            Button(engine.playerState.isPlaying ? L10n.pause : L10n.play) {
                engine.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button(L10n.nextTrack) {
                engine.nextTrack()
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)

            Button(L10n.previousTrack) {
                engine.previousTrack()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Divider()

            Button(L10n.increaseVolume) {
                engine.adjustVolume(by: 10)
            }
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button(L10n.decreaseVolume) {
                engine.adjustVolume(by: -10)
            }
            .keyboardShortcut(.downArrow, modifiers: .command)

            Button(engine.playerState.isMuted ? L10n.unmute : L10n.mute) {
                engine.toggleMute()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button(L10n.likeCurrentSong) {
                engine.toggleLike()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button(L10n.toggleShuffle) {
                engine.toggleShuffle()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button(L10n.cycleRepeat) {
                engine.cycleRepeat()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }

        CommandGroup(after: .sidebar) {
            Button(L10n.showPlayingNext) {
                toggleInspectorTab(.queue)
            }
            .keyboardShortcut("u", modifiers: .command)

            Button(L10n.showLyrics) {
                toggleInspectorTab(.lyrics)
            }
            .keyboardShortcut("l", modifiers: .command)

            Divider()

            Button(
                engine.showEmbeddedPlayerSheet
                    ? L10n.hideEmbeddedPlayerMenu
                    : L10n.showEmbeddedPlayerMenu
            ) {
                engine.showEmbeddedPlayerSheet.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }

    private func toggleInspectorTab(_ tab: InspectorTab) {
        withAnimation(AppAnimations.standard) {
            if showInspector && inspectorTab == tab {
                showInspector = false
            } else {
                inspectorTab = tab
                showInspector = true
            }
        }
    }
}
