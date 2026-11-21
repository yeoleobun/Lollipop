# Lollipop (YoMusic) Implementation & Architecture Guide

This guide explains how the Lollipop macOS app is organized, how SwiftUI separates component structure from visual style, and the concrete **DO / DON'T** rules to follow when maintaining or extending the project.

---

## 1. Architecture & Directory Map

```text
Sources/Lollipop/
├── App/                 # App entry point, NSApplicationDelegate, macOS menu bar commands
├── Constants/           # Typed constants (app config, SF Symbols, YouTube Music IDs & bridge protocol)
├── Localization/        # Centralized en / zh-Hans copy and formatters (L10n)
├── DesignSystem/        # Theme tokens (colors, fonts, metrics, animations), ButtonStyles, ViewModifiers
├── Models/              # Pure domain models + navigation/routing state & MusicItemNavigator
├── Engine/              # WKWebView audio engine, cache store, LRCLIB client, AppKit helpers
├── Resources/Bridge/    # Real JavaScript modules injected into YouTube Music WKWebView
└── Views/
    ├── MainView.swift   # Split-view shell, route dispatcher, centralized sheets & alerts
    ├── Navigation/      # SidebarView & account footer
    ├── Components/      # Reusable styled UI primitives (ArtworkView, TrackRowView, Scrubber, Menus...)
    ├── Player/          # NowPlayingBar, FullScreenPlayerView, PlayerLyricsView, PlayerQueueView
    └── Pages/           # Top-level destinations (Browse, Search, Library, Artist, Collection) & Sheets/
```

### Dependency Rules
Keep dependencies flowing in one direction:

- **`Constants/` & `Localization/`**: Depend only on Foundation / CoreGraphics. Never import SwiftUI or Engine types.
- **`DesignSystem/`**: Depends on SwiftUI / AppKit and `Constants/`. Never imports `Engine/` or `Models/`.
- **`Models/`**: Pure structs/enums plus `MusicItemNavigator` routing logic. Never imports SwiftUI views.
- **`Engine/`**: Owns `WKWebView`, `NSPasteboard`, network calls (`SyncedLyricsProvider`), and `MusicCacheStore`. Never defines SwiftUI pages.
- **`Views/`**: Declarative UI only. **Never** import `WebKit`, call `NSPasteboard`, embed multi-line JavaScript, or branch on raw Innertube IDs directly inside a view.

---

## 2. Separating Component Definition from Style in SwiftUI

In web development, structure lives in HTML/JSX and styling lives in CSS. In SwiftUI, a view's `body` handles **layout and behavior**, while **visual styling** is extracted into reusable tokens, `ButtonStyle`s, `ViewModifier`s, and style enums under `DesignSystem/`:

| Concern | Where It Lives | Examples in Lollipop |
|---|---|---|
| Colors, fonts, spacing, radii, animations | `DesignSystem/AppTheme.swift` | `AppColors.accent`, `AppTypography.pageTitle`, `AppMetrics.pageBottomClearance`, `AppAnimations.overlaySpring` |
| Button appearance & press/disabled states | `DesignSystem/ButtonStyles.swift` | `PrimaryCapsuleButtonStyle`, `SecondaryCapsuleButtonStyle`, `FilterPillButtonStyle`, `PlayerIconButtonStyle` |
| Reusable container chrome & elevation | `DesignSystem/ViewModifiers.swift`, `GlassModifiers.swift` | `.pageScrollContent()`, `.pageCenteredState()`, `.pageBackground()`, `.mediaCardElevation(...)`, `GroupedFormSection`, `.liquidGlassCapsule()` |
| Multi-variant component skins | Component `*Style` enums | `PlaybackScrubberStyle`, `VolumeControlStyle`, `TrackEllipsisMenuStyle`, `AmbientBackdropStyle` |

### Styling DOs and DON'Ts

- **DO** put shared colors, spacing, corner radii, and animations in `AppTheme.swift` (`AppColors`, `AppTypography`, `AppMetrics`, `AppAnimations`).
- **DON'T** duplicate `.font(.system(...))`, `.padding(...)`, `.background(...)`, or `.foregroundStyle(...)` chains on every button across pages—create or reuse a `ButtonStyle` in `DesignSystem/ButtonStyles.swift`.
- **DO** use `.pageScrollContent()`, `.pageCenteredState()`, and `.pageBackground()` on page views so every page clears the floating `NowPlayingBar` consistently via `AppMetrics.pageBottomClearance`.
- **DON'T** hardcode magic offsets in one component to compensate for another component's dimensions (for example, `HorizontalCarouselView` accepts `cardSize` directly to vertically center `<` / `>` chevrons on the artwork rather than guessing caption height).
- **DO** parameterize a shared component with a `*Style` enum when its behavior is identical across two surfaces (such as `PlaybackScrubberView` supporting `.compactBar` and `.fullScreen`, or `VolumeControlView` supporting `.popoverButton` and `.inlinePill`).
- **DON'T** copy-paste an entire view or menu across files just to change padding or tint color.

---

## 3. macOS-Specific SwiftUI Rules (DOs & DON'Ts)

macOS SwiftUI behaves differently from iOS and web UI in several important ways:

### Sheets, Popovers & Lists
- **DO** host shared modal sheets once at a parent coordinator (`MainView` binds `.sheet(item: $engine.playlistEditorMode)`), and let child rows trigger them via engine methods (`engine.presentCreatePlaylist(...)`).
- **DON'T** attach `.sheet(...)` or `.alert(...)` modifiers inside individual `ForEach` rows (`TrackRowView`)—on macOS this creates hundreds of presentation observers and hurts scroll performance.

### Buttons, Hit Testing & Hover
- **DO** apply `.contentShape(Rectangle())` (or `RoundedRectangle(...)`) on padded `HStack` rows and icon buttons; otherwise transparent padding inside a custom `.buttonStyle(.plain)` label is not clickable or hoverable on macOS.
- **DO** prefer custom `ButtonStyle` structs over ad-hoc `.buttonStyle(.plain)` + inline styling so macOS focus, disabled opacity, and pressed feedback work uniformly.
- **DON'T** rely on `onTapGesture` alone for primary controls when a `Button` works—buttons participate automatically in macOS accessibility, keyboard focus, and `.keyboardShortcut(...)`.

### Window Chrome, Menus & Ergonomics
- **DO** keep top-left controls clear of the macOS traffic-light buttons when using `.windowStyle(.hiddenTitleBar)` (see `AppMetrics.trafficLightsLeadingInset` in `FullScreenPlayerView`).
- **DO** add `.help(L10n.<tooltip>)` to icon-only toolbar/player buttons, `.contextMenu` to media rows/cards, and macOS menu bar shortcuts in `App/AppCommands.swift`.
- **DO** configure `UserDefaults` (`AppleShowScrollBars = "WhenScrolling"`) in `AppDelegate` so macOS doesn't render legacy static scrollbar tracks when a mouse is attached.

### AppKit, WebKit & Audio Lifecycle
- **DO** isolate AppKit (`NSOpenPanel`, `NSPasteboard`) and `WKWebView` bridges in `Engine/` (`PasteboardHelper`, `SharedWebViewHost`, `GoogleSignInWebView`).
- **DON'T** tear down or remove `engine.webView` from the view hierarchy while audio is playing—`MainView` keeps `SharedWebViewHost` mounted in a `1×1`, `0.001`-opacity background host whenever `EmbeddedPlayerSheet` is closed so WebKit never suspends background audio.
- **DON'T** publish a second `MPNowPlayingInfoCenter` payload from Swift; WebKit already publishes `navigator.mediaSession` to macOS Control Center (`NowPlayingManager` explains this contract).

### Swift 6 Strict Concurrency & Toolchain Compatibility
- **DO** keep `typealias ViewState<Value> = SwiftUI.State<Value>` (`@ViewState`) in `AppTheme.swift` so the target compiles cleanly with both Xcode and standalone macOS Command Line Tools.
- **DO** place constants in caseless `enum`s and compute SwiftUI value tokens (`Color`, `Font`, `Animation`) via `static var` so Swift 6 strict concurrency (`Sendable` / `@MainActor`) stays warning-free.

---

## 4. Constants, Localization & JS Bridge Rules

### Constants & Localization
- **DO** add every SF Symbol string to `AppSymbols.swift`—never scatter raw `"play.fill"` or `"ellipsis"` strings through `Views/` or `Models/`.
- **DO** add every user-facing string (English + Simplified Chinese) to `L10n.swift` (`L10n.isChinese` stays `private` inside `L10n.swift`).
- **DON'T** write inline `isChinese ? ... : ...` checks or unlocalized English menu/empty-state literals inside `Views/` or `AppCommands`.
- **DO** put all YouTube Music browse IDs (`FEmusic_*`, `VLLM`), ID prefixes (`UC`, `MPREb_`, `VL`), search params, and bridge JS call strings in `YouTubeMusicConstants.swift`, and route item taps through `MusicItemNavigator`.

### JavaScript Bridge (`Sources/Lollipop/Resources/Bridge/`)
The WebView bridge lives as real `.js` modules rather than raw Swift string literals:

1. `01-core.js` — Constants, DOM selectors, `MediaSession` patch, audio-only CSS injection, `SAPISIDHASH` auth, `innertube()` client, and shared formatters.
2. `02-parsers.js` — Innertube JSON section, shelf, track, card, and lyrics parsers.
3. `03-player.js` — Player DOM/API state reader, 250ms state ticker (`playerState` / `engineReady`), and playback transport controls.
4. `04-api.js` — Public `window.__lollipop` API methods and cleanup of temporary `window.__lollipopInternal`.
5. `disable-webauthn.js` — Document-start script injected into `GoogleSignInWebView` to disable unsupported `WKWebView` passkey prompts.

- **DO** keep selectors and Innertube browse constants grouped at the top of `01-core.js`, and keep `YouTubeMusicConstants.Bridge` in Swift synchronized with method/event names in `04-api.js` and `03-player.js`.
- **DO** run `node --check Sources/Lollipop/Resources/Bridge/*.js` after editing any JS file.
- **DON'T** embed multi-line JavaScript strings inside `.swift` files, and don't leave temporary helpers on `window` outside `window.__lollipop`.
- **DO** bundle `Resources/Bridge` in both `Package.swift` (`.copy("Resources/Bridge")`) and `scripts/bundle_app.sh`.

---

## 5. Pre-Change Checklist

Before finishing any PR or feature change:

1. **No inline styles or magic clearances**: New buttons use `DesignSystem/ButtonStyles.swift`; pages use `.pageScrollContent()` / `.pageBackground()`.
2. **No raw literals**: New strings live in `L10n.swift`, symbols in `AppSymbols.swift`, Innertube constants in `YouTubeMusicConstants.swift`.
3. **JS validated**: If `Resources/Bridge/*.js` changed, `node --check` passes and method signatures match `YouTubeMusicConstants.Bridge` & `YouTubeMusicEngine`.
4. **Builds pass cleanly**: Both `swift build` and `./scripts/bundle_app.sh` exit `0` with zero compiler warnings.
