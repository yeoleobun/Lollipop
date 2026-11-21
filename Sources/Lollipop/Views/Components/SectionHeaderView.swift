import SwiftUI

/// Reusable section heading with optional uppercase eyebrow and optional drill-down chevron.
struct SectionHeaderView: View {
    let title: String
    var subtitle: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle.uppercased())
                    .font(AppTypography.sectionEyebrow)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            if let onTap {
                Button(action: onTap) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(.primary)
                        Image(systemName: AppSymbols.chevronRight)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(.primary)
            }
        }
    }
}
