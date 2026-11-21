import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Modeled directly after macOS 27 Apple Podcasts' "New Station" sheet:
/// centered bold title, grouped rounded-card form sections with hairline dividers,
/// native pop-up dropdowns, accent-colored picker row, and bottom-right Cancel / OK buttons.
struct PlaylistEditorSheet: View {
    let mode: PlaylistEditorMode
    let engine: YouTubeMusicEngine
    var onCompleted: ((String?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @ViewState private var titleText: String = ""
    @ViewState private var descriptionText: String = ""
    @ViewState private var privacy: PlaylistPrivacyOption = .private
    @ViewState private var selectedCoverURL: URL? = nil
    @ViewState private var resetExistingCover = false
    @ViewState private var isSubmitting = false

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingPlaylistId: String? {
        if case .edit(let pid, _, _) = mode { return pid }
        return nil
    }

    private var previewCoverString: String {
        if let selectedCoverURL {
            return selectedCoverURL.absoluteString
        }
        if resetExistingCover {
            return ""
        }
        if let pid = existingPlaylistId {
            return engine.cache.resolvedPlaylistArtwork(
                for: pid,
                remoteArtwork: "",
                tracks: engine.cache.collection(for: pid)?.tracks ?? []
            )
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditMode ? L10n.editPlaylist : L10n.newPlaylist)
                .font(AppTypography.sheetTitle)
                .foregroundStyle(.primary)
                .padding(.top, 20)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 18) {
                GroupedFormSection(title: L10n.playlistSection) {
                    TextField(L10n.playlistTitlePlaceholder, text: $titleText)
                        .textFieldStyle(.plain)
                        .font(AppTypography.formBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    Divider().padding(.leading, 14).opacity(0.45)

                    TextField(L10n.playlistDescPlaceholder, text: $descriptionText)
                        .textFieldStyle(.plain)
                        .font(AppTypography.formBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    Divider().padding(.leading, 14).opacity(0.45)

                    HStack {
                        Text(L10n.playlistPrivacy)
                            .font(AppTypography.formBody)
                            .foregroundStyle(.primary)
                        Spacer()
                        Picker("", selection: $privacy) {
                            ForEach(PlaylistPrivacyOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }

                GroupedFormSection(title: L10n.cover) {
                    HStack(spacing: 12) {
                        Button {
                            pickCoverImage()
                        } label: {
                            Text(L10n.chooseCover)
                                .font(AppTypography.formBody)
                                .foregroundStyle(AppColors.accent)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if !previewCoverString.isEmpty {
                            ArtworkView(urlString: previewCoverString, size: 28, cornerRadius: 6)

                            Button {
                                selectedCoverURL = nil
                                resetExistingCover = true
                            } label: {
                                Image(systemName: AppSymbols.closeCircleFill)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(L10n.resetCover)
                        } else {
                            Text(L10n.defaultCover)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }
            .padding(.horizontal, 26)

            Spacer(minLength: 24)

            HStack(spacing: 10) {
                Spacer()

                Button(L10n.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.regular)

                Button(isSubmitting ? AppConstants.ellipsis : L10n.ok) {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                .controlSize(.regular)
                .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 20)
        }
        .frame(width: AppMetrics.playlistEditorWidth)
        .background(AppColors.windowBackground)
        .onAppear {
            if case .edit(_, let title, let desc) = mode {
                titleText = title
                descriptionText = desc
            }
        }
    }

    private func pickCoverImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            selectedCoverURL = url
            resetExistingCover = false
        }
    }

    private func submit() {
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        isSubmitting = true

        Task {
            switch mode {
            case .create(let initialVideoId):
                let newBrowseId = await engine.createPlaylist(
                    title: trimmedTitle,
                    description: descriptionText,
                    privacyStatus: privacy.rawValue,
                    initialVideoId: initialVideoId
                )
                if let newBrowseId, let coverURL = selectedCoverURL {
                    engine.cache.setCustomPlaylistCover(for: newBrowseId, from: coverURL)
                }
                isSubmitting = false
                dismiss()
                onCompleted?(newBrowseId)

            case .edit(let playlistId, _, _):
                let ok = await engine.editPlaylistMetadata(
                    playlistId: playlistId,
                    title: trimmedTitle,
                    description: descriptionText,
                    privacyStatus: privacy.rawValue
                )
                if let coverURL = selectedCoverURL {
                    engine.cache.setCustomPlaylistCover(for: playlistId, from: coverURL)
                } else if resetExistingCover {
                    engine.cache.removeCustomPlaylistCover(for: playlistId)
                }
                isSubmitting = false
                if ok {
                    dismiss()
                    onCompleted?(playlistId)
                }
            }
        }
    }
}
