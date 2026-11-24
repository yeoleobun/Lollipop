import SwiftUI

/// Reusable section heading with optional uppercase eyebrow, drill-down chevron,
/// and a native macOS-style accent Play All action.
struct SectionHeaderView: View {
    let title: String
    var subtitle: String? = nil
    var onTap: (() -> Void)? = nil
    var onPlayAll: (() -> Void)? = nil

    @ViewState private var isTitleHovered = false
    @ViewState private var isPlayAllHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle.uppercased())
                        .font(AppTypography.sectionEyebrow)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }

                if let onTap {
                    Button(action: onTap) {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(.primary)
                            Image(systemName: AppSymbols.chevronRight)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isTitleHovered ? .primary : .tertiary)
                                .offset(x: isTitleHovered ? 2 : 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(AppAnimations.fastHover) {
                            isTitleHovered = hovering
                        }
                    }
                } else {
                    Text(title)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.primary)
                }
            }

            Spacer()

            if let onPlayAll {
                Button(action: onPlayAll) {
                    HStack(spacing: 5) {
                        Image(systemName: AppSymbols.playFill)
                            .font(.system(size: 10, weight: .semibold))
                        Text(L10n.playAll)
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppColors.accent.opacity(isPlayAllHovered ? 0.12 : 0.0))
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(AppAnimations.fastHover) {
                        isPlayAllHovered = hovering
                    }
                }
            }
        }
    }
}
