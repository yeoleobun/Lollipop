# Lollipop

A native macOS YouTube Music client written in Swift 6 and SwiftUI, designed around Apple Music for macOS and the latest macOS Liquid Glass guidelines, powered by a hidden audio-only embedded player.

## Demo

[Watch the UI Demo (`docs/demo.mp4`)](docs/demo.mp4)

## Install

### Homebrew (Recommended)

```bash
brew tap yeoleobun/tap
brew install --cask yeoleobun/tap/lollipop
```

Upgrade anytime with:

```bash
brew upgrade --cask lollipop
```

### Direct Download

Download the latest macOS Apple Silicon build from [GitHub Releases](https://github.com/yeoleobun/Lollipop/releases/latest) (`Lollipop-*-macOS-arm64.dmg`).

## Features

- **Apple Music-Inspired Native UI**:
  - `NavigationSplitView` sidebar with **YouTube Music** (Home, Explore, Charts, Search), **Library** (Liked Songs, Songs, Albums, Artists), and synced **Playlists**.
  - Editorial horizontal carousels, 4-row Quick Picks grids, split-header Album/Playlist detail views with ambient blurred artwork, and animated equalizer bars on the playing track.
  - Floating **Liquid Glass** Now Playing bar (`glassEffect` on macOS 26+, `.ultraThinMaterial` fallback on macOS 15) with interactive scrub bar, volume popover, and full-screen immersive Lyrics / Up Next overlay.
- **Native Google Sign-In Modal**:
  - Click **Sign In** to open a compact, auto-closing Google Sign-In sheet sharing `WKWebsiteDataStore.default()` (so your session persists across restarts without interrupting playback). Supports macOS **Right-click → AutoFill → Passwords** and Google Phone Prompts.
- **Hidden Embedded Audio-Only Engine**:
  - Runs `music.youtube.com` in a persistent hidden `WKWebView` (1×1 background host so WebKit never suspends audio, with `<video>` rendering visually suppressed).
  - Reveal the embedded player on demand (`⌘⇧P`) if needed; closing it keeps audio playing uninterrupted.
- **Native macOS Integration**:
  - Hardware media keys, Control Center, and macOS Now Playing integration via WebKit's `MediaSession`.
  - Full menu bar playback & view shortcuts (`Space`, `⌘→`, `⌘←`, `⌘↑`, `⌘↓`, `⌘U` Queue, `⌘L` Lyrics, `⌘⇧P` Embedded Player).

## Project Structure & Documentation

- `Sources/Lollipop/App/` — App lifecycle & macOS menu bar commands (`AppCommands`)
- `Sources/Lollipop/Constants/` & `Localization/` — Typed app/symbol/YouTube Music constants & `L10n` (`en` / `zh-Hans`)
- `Sources/Lollipop/DesignSystem/` — Theme tokens (`AppTheme`), `ButtonStyle`s, Liquid Glass & layout `ViewModifier`s
- `Sources/Lollipop/Models/` & `Engine/` — Domain/navigation models, `YouTubeMusicEngine`, `MusicCacheStore`, `SyncedLyricsProvider`
- `Sources/Lollipop/Resources/Bridge/` — Modular `.js` bridge scripts (`01-core.js` – `04-api.js`, `disable-webauthn.js`)
- `Sources/Lollipop/Views/` — `Navigation/`, `Components/`, `Player/`, `Pages/`, and `Pages/Sheets/`

See [docs/IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md) for the architecture overview, SwiftUI style-separation patterns, and macOS implementation DOs & DON'Ts.

## Running

```bash
# Run directly with SwiftPM
swift run

# Or package and launch the macOS .app bundle
./scripts/bundle_app.sh
open build/Lollipop.app
```
