import AppKit
import SwiftUI

struct UpdateSheet: View {
    let updater: UpdateChecker
    @Environment(\.dismiss) private var dismiss
    @ViewState private var copiedBrewCommand = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }

                Text(L10n.updateAvailableTitle)
                    .font(.system(size: 17, weight: .bold))

                if let release = updater.availableUpdate {
                    Text(L10n.updateVersionSummary(current: updater.currentVersion, latest: release.version))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)

            if let notes = updater.availableUpdate?.releaseNotes, !notes.isEmpty {
                ScrollView {
                    Text(notes)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.primary.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
            }

            // Homebrew upgrade command pill
            HStack(spacing: 10) {
                Text(UpdateChecker.brewUpgradeCommand)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                Button {
                    PasteboardHelper.copyString(UpdateChecker.brewUpgradeCommand)
                    copiedBrewCommand = true
                } label: {
                    Text(copiedBrewCommand ? L10n.copied : L10n.copy)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )

            HStack(spacing: 10) {
                Button(L10n.later) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if let release = updater.availableUpdate {
                    Button(L10n.downloadUpdate) {
                        NSWorkspace.shared.open(release.downloadURL ?? release.releaseURL)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                }
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
