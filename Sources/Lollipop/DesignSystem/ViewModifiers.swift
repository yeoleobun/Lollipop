import SwiftUI

// MARK: - Page Layout Modifiers

struct PageScrollContentModifier: ViewModifier {
    var horizontalPadding: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }
}

struct PageCenteredStateModifier: ViewModifier {
    var bottomOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, bottomOffset)
    }
}

struct PageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.pageBackground)
    }
}

// MARK: - Media Card Elevation Modifier

struct MediaCardElevationModifier: ViewModifier {
    let isHovered: Bool
    let isCircular: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                let shadowColor = Color.black.opacity(isHovered ? 0.24 : 0.13)
                let shadowRadius: CGFloat = isHovered ? 14 : 8
                let shadowY: CGFloat = isHovered ? 7 : 4

                if isCircular {
                    Circle()
                        .fill(AppColors.windowBackground)
                        .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColors.windowBackground)
                        .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
                }
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(AppAnimations.cardHoverSpring, value: isHovered)
    }
}

// MARK: - Grouped Form Card

struct GroupedFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(AppTypography.formHeader)
                .foregroundStyle(AppColors.sidebarItemText)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.formCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppColors.formCardStroke, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - View Extensions

extension View {
    func pageScrollContent(
        horizontal: CGFloat = AppMetrics.pageHorizontalPadding,
        top: CGFloat = AppMetrics.pageTopPadding,
        bottom: CGFloat = AppMetrics.pageBottomClearance
    ) -> some View {
        modifier(
            PageScrollContentModifier(
                horizontalPadding: horizontal,
                topPadding: top,
                bottomPadding: bottom
            )
        )
    }

    func pageCenteredState(bottomOffset: CGFloat = AppMetrics.emptyStateBottomOffset) -> some View {
        modifier(PageCenteredStateModifier(bottomOffset: bottomOffset))
    }

    func pageBackground() -> some View {
        modifier(PageBackgroundModifier())
    }

    func mediaCardElevation(
        isHovered: Bool,
        isCircular: Bool,
        cornerRadius: CGFloat = AppMetrics.cardCornerRadius
    ) -> some View {
        modifier(
            MediaCardElevationModifier(
                isHovered: isHovered,
                isCircular: isCircular,
                cornerRadius: cornerRadius
            )
        )
    }
}
