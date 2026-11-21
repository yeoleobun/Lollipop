import SwiftUI

/// Horizontal media carousel with subtle Apple Music-style hover `<` / `>` paging buttons
/// centered on the artwork height and unclipped card shadows.
struct HorizontalCarouselView: View {
    let items: [MusicItem]
    var cardSize: CGFloat = AppMetrics.cardDefaultSize
    let onTap: (MusicItem) -> Void
    let onPlay: (MusicItem) -> Void
    let onOpenRoute: (NavigationRoute) -> Void

    @ViewState private var isHovered = false
    @ViewState private var anchorIndex = 0

    private let verticalInset: CGFloat = 10

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: AppMetrics.carouselSpacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            MediaCardView(
                                item: item,
                                size: cardSize,
                                onTap: { onTap(item) },
                                onPlay: { onPlay(item) },
                                onOpenRoute: onOpenRoute
                            )
                            .id(idx)
                        }
                    }
                    .padding(.vertical, verticalInset)
                }
                .scrollClipDisabled()

                if isHovered && items.count > 4 {
                    HStack {
                        if anchorIndex > 0 {
                            chevronButton(systemImage: AppSymbols.chevronLeft) {
                                let target = max(0, anchorIndex - 3)
                                anchorIndex = target
                                withAnimation(AppAnimations.carouselPage) {
                                    proxy.scrollTo(target, anchor: .leading)
                                }
                            }
                            .padding(.leading, -10)
                        }

                        Spacer()

                        if anchorIndex < items.count - 3 {
                            chevronButton(systemImage: AppSymbols.chevronRight) {
                                let target = min(items.count - 1, anchorIndex + 3)
                                anchorIndex = target
                                withAnimation(AppAnimations.carouselPage) {
                                    proxy.scrollTo(target, anchor: .leading)
                                }
                            }
                            .padding(.trailing, -10)
                        }
                    }
                    .frame(height: cardSize)
                    .padding(.top, verticalInset)
                    .transition(.opacity)
                }
            }
            .onHover { hovering in
                withAnimation(AppAnimations.fastHover) {
                    isHovered = hovering
                }
            }
        }
    }

    private func chevronButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
        }
        .buttonStyle(
            FloatingCircleIconButtonStyle(
                size: AppMetrics.carouselChevronSize,
                foreground: .primary,
                background: AnyShapeStyle(.regularMaterial),
                borderColor: Color.primary.opacity(0.10),
                borderWidth: 0.75,
                shadowColor: .black.opacity(0.16),
                shadowRadius: 8,
                shadowY: 3
            )
        )
    }
}
