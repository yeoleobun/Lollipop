import SwiftUI

// MARK: - Capsule Action Button Styles

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 20
    var verticalPadding: CGFloat = 8
    var font: Font = .system(size: 13, weight: .semibold)

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(AppColors.accent, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.45)
    }
}

struct SecondaryCapsuleButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 8
    var font: Font = .system(size: 13, weight: .semibold)
    var fill: Color = AppColors.subtleFill

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(.primary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(fill, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1.0) : 0.45)
    }
}

struct DestructiveCapsuleButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.red)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(AppColors.destructivePillFill, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

// MARK: - Filter Pill Button Style

enum FilterPillMode {
    case accent
    case invertedPrimary
}

struct FilterPillButtonStyle: ButtonStyle {
    let isSelected: Bool
    var mode: FilterPillMode = .accent

    func makeBody(configuration: Configuration) -> some View {
        let horizontalPadding: CGFloat = mode == .accent ? 15 : 14
        let verticalPadding: CGFloat = mode == .accent ? 6.5 : 6
        let font = mode == .accent ? AppTypography.libraryFilterPill : AppTypography.pillButton(isSelected: isSelected)

        let foreground: Color = {
            guard isSelected else { return .primary }
            return mode == .accent ? .white : AppColors.pageBackground
        }()

        let background: AnyShapeStyle = {
            switch mode {
            case .accent:
                return isSelected
                    ? AnyShapeStyle(AppColors.accent)
                    : AnyShapeStyle(AppColors.subtleFill)
            case .invertedPrimary:
                return isSelected
                    ? AnyShapeStyle(Color.primary)
                    : AnyShapeStyle(Color.clear)
            }
        }()

        configuration.label
            .font(font)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .opacity(configuration.isPressed ? 0.78 : 1.0)
    }
}

// MARK: - Circle Icon Button Styles

struct FloatingCircleIconButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var foreground: Color = .primary
    var background: AnyShapeStyle = AnyShapeStyle(.regularMaterial)
    var borderColor: Color? = Color.primary.opacity(0.10)
    var borderWidth: CGFloat = 0.75
    var shadowColor: Color = .black.opacity(0.16)
    var shadowRadius: CGFloat = 8
    var shadowY: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .overlay {
                if let borderColor {
                    Circle().strokeBorder(borderColor, lineWidth: borderWidth)
                }
            }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
    }
}

struct PlayerIconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    var foreground: Color = .primary
    var activeBackground: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(activeBackground, in: Circle())
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
