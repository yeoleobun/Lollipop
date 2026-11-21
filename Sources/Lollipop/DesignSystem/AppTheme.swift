import AppKit
import SwiftUI

/// Explicit alias to the `SwiftUI.State` property wrapper so the project builds cleanly
/// with both Xcode and standalone macOS Command Line Tools (where `SwiftUIMacros` is absent).
typealias ViewState<Value> = SwiftUI.State<Value>

extension Color {
    /// Apple Music signature vibrant red-pink accent.
    static var musicAccent: Color { AppColors.accent }
}

// MARK: - Colors

enum AppColors {
    static let accent = Color(red: 0.98, green: 0.14, blue: 0.27)
    static let fullPlayerBackground = Color(red: 0.10, green: 0.10, blue: 0.12)

    static var pageBackground: Color { Color(nsColor: .textBackgroundColor) }
    static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }

    static var sidebarActivePill: Color { Color.primary.opacity(0.085) }
    static var sidebarItemText: Color { Color.primary.opacity(0.88) }
    static var subtleFill: Color { Color.primary.opacity(0.08) }
    static var searchFieldFill: Color { Color.primary.opacity(0.065) }
    static var hoverRowFill: Color { Color.primary.opacity(0.06) }
    static var zebraRowFill: Color { Color.primary.opacity(0.025) }
    static var activeTrackRowFill: Color { accent.opacity(0.10) }
    static var formCardFill: Color { Color.primary.opacity(0.038) }
    static var formCardStroke: Color { Color.primary.opacity(0.06) }
    static var artworkBorder: Color { Color.primary.opacity(0.08) }
    static var artworkPlaceholderTop: Color { Color.secondary.opacity(0.16) }
    static var artworkPlaceholderBottom: Color { Color.secondary.opacity(0.08) }
    static var explicitBadgeFill: Color { Color.secondary.opacity(0.18) }
    static var avatarPlaceholderFill: Color { Color.primary.opacity(0.09) }
    static var destructivePillFill: Color { Color.red.opacity(0.09) }
    static var secondaryCancelPillFill: Color { Color.primary.opacity(0.07) }
}

// MARK: - Typography

enum AppTypography {
    static var pageTitle: Font { .system(size: 30, weight: .bold) }
    static var libraryTitle: Font { .system(size: 32, weight: .bold) }
    static var heroTitle: Font { .system(size: 28, weight: .bold) }
    static var artistHeroTitle: Font { .system(size: 32, weight: .bold) }
    static var sectionTitle: Font { .system(size: 18, weight: .bold) }
    static var librarySectionTitle: Font { .system(size: 19, weight: .bold) }
    static var searchSectionTitle: Font { .system(size: 16, weight: .bold) }
    static var sectionEyebrow: Font { .system(size: 11, weight: .semibold) }

    static var sidebarHeader: Font { .system(size: 11.5, weight: .semibold) }
    static func sidebarItem(isSelected: Bool) -> Font {
        .system(size: 13.5, weight: isSelected ? .medium : .regular)
    }

    static var cardTitle: Font { .system(size: 13, weight: .medium) }
    static var cardSubtitle: Font { .system(size: 12) }
    static var explicitBadge: Font { .system(size: 9, weight: .bold) }

    static func trackTitle(isCurrent: Bool) -> Font {
        .system(size: 13.5, weight: isCurrent ? .semibold : .medium)
    }
    static var trackMeta: Font { .system(size: 12) }
    static var trackIndex: Font { .system(size: 13, weight: .regular).monospacedDigit() }
    static var trackDuration: Font { .system(size: 12).monospacedDigit() }

    static var sheetTitle: Font { .system(size: 15, weight: .bold) }
    static var accountTitle: Font { .system(size: 19, weight: .bold) }
    static var signInIntroTitle: Font { .system(size: 17, weight: .bold) }
    static var formHeader: Font { .system(size: 12.5, weight: .semibold) }
    static var formBody: Font { .system(size: 13.5) }

    static func pillButton(isSelected: Bool) -> Font {
        .system(size: 12.5, weight: isSelected ? .semibold : .medium)
    }
    static var libraryFilterPill: Font { .system(size: 13, weight: .semibold) }
}

// MARK: - Metrics & Spacing

enum AppMetrics {
    // Window & Split View
    static let mainWindowMinWidth: CGFloat = 920
    static let mainWindowMinHeight: CGFloat = 600
    static let mainWindowDefaultWidth: CGFloat = 1220
    static let mainWindowDefaultHeight: CGFloat = 800
    static let sidebarMinWidth: CGFloat = 205
    static let sidebarIdealWidth: CGFloat = 222
    static let sidebarMaxWidth: CGFloat = 270
    static let hiddenWebViewFrame = NSRect(x: 0, y: 0, width: 1024, height: 700)

    // Sheets
    static let embeddedSheetMinWidth: CGFloat = 860
    static let embeddedSheetMinHeight: CGFloat = 580
    static let playlistEditorWidth: CGFloat = 480
    static let signInIntroSize = CGSize(width: 430, height: 460)
    static let signInWebSize = CGSize(width: 460, height: 620)
    static let accountSheetSize = CGSize(width: 430, height: 390)

    // Page Layout & Floating Player Clearance
    static let pageHorizontalPadding: CGFloat = 34
    static let pageTopPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 28
    static let detailSectionSpacing: CGFloat = 26
    static let playerBarHeight: CGFloat = 56
    static let playerBarHorizontalPadding: CGFloat = 18
    static let playerBarOuterHorizontalMargin: CGFloat = 24
    static let playerBarBottomMargin: CGFloat = 16
    static let pageBottomClearance: CGFloat = 100
    static let emptyStateBottomOffset: CGFloat = 76
    static let trafficLightsLeadingInset: CGFloat = 78

    // Media Cards & Grid
    static let cardDefaultSize: CGFloat = 176
    static let cardLibrarySize: CGFloat = 168
    static let cardSectionGridSize: CGFloat = 172
    static let cardGridMinSize: CGFloat = 168
    static let cardGridMaxSize: CGFloat = 196
    static let cardCornerRadius: CGFloat = 12
    static let carouselSpacing: CGFloat = 18
    static let carouselChevronSize: CGFloat = 32

    // Track Rows & Quick Picks
    static let trackArtworkSize: CGFloat = 42
    static let trackArtworkCornerRadius: CGFloat = 7
    static let trackRowCornerRadius: CGFloat = 8
    static let trackRowHorizontalPadding: CGFloat = 10
    static let trackRowVerticalPadding: CGFloat = 7
    static let searchArtworkSize: CGFloat = 50
    static let searchArtworkCornerRadius: CGFloat = 9
    static let quickPicksWidth: CGFloat = 310
    static let quickPicksRowHeight: CGFloat = 56
    static let maxAlbumLabelWidth: CGFloat = 180

    // Hero Headers
    static let heroBannerHeight: CGFloat = 224
    static let artistHeroBannerHeight: CGFloat = 220
    static let heroCornerRadius: CGFloat = 20
    static let heroArtworkSize: CGFloat = 176
    static let heroArtworkCornerRadius: CGFloat = 14
    static let artistHeroArtworkSize: CGFloat = 168
}

// MARK: - Animations

enum AppAnimations {
    static var standard: Animation { .easeInOut(duration: 0.2) }
    static var fastHover: Animation { .easeInOut(duration: 0.15) }
    static var scrubberHover: Animation { .easeInOut(duration: 0.12) }
    static var routeSpring: Animation { .spring(response: 0.28, dampingFraction: 0.86) }
    static var sidebarSpring: Animation { .spring(response: 0.28, dampingFraction: 0.82) }
    static var overlaySpring: Animation { .spring(response: 0.3, dampingFraction: 0.88) }
    static var cardHoverSpring: Animation { .spring(response: 0.25, dampingFraction: 0.8) }
    static var lyricsScroll: Animation { .easeInOut(duration: 0.38) }
    static var lyricsActiveRow: Animation { .spring(response: 0.3, dampingFraction: 0.82) }
    static var carouselPage: Animation { .easeInOut(duration: 0.3) }
}
