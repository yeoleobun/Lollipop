import SwiftUI

struct SidebarView: View {
    let engine: YouTubeMusicEngine
    let updateChecker: UpdateChecker
    @Binding var selection: SidebarDestination
    @Binding var playlistToDelete: UserPlaylist?
    let onSelect: (SidebarDestination) -> Void

    @Environment(\.controlActiveState) private var controlActiveState
    @ViewState private var isYourMusicExpanded = true
    @ViewState private var isPlaylistsExpanded = true
    @Namespace private var sidebarHighlightNamespace

    private var sidebarIconColor: Color {
        controlActiveState == .inactive ? .secondary : AppColors.accent
    }

    var body: some View {
        List {
            Section {
                sidebarItem(.search)
                sidebarItem(.home)
                sidebarItem(.explore)
                sidebarItem(.charts)
            }

            Section(isExpanded: $isYourMusicExpanded) {
                sidebarItem(.likedSongs)
                sidebarItem(.history)
                sidebarItem(.library)
            } header: {
                Text(L10n.yourMusic)
                    .font(AppTypography.sidebarHeader)
                    .foregroundStyle(.secondary)
            }

            Section(isExpanded: $isPlaylistsExpanded) {
                if engine.userPlaylists.isEmpty {
                    Text(engine.isSignedIn ? L10n.noPlaylistsYet : L10n.signInForPlaylists)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                } else {
                    ForEach(engine.userPlaylists) { playlist in
                        playlistSidebarItem(playlist)
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Text(L10n.playlists)
                        .font(AppTypography.sidebarHeader)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if engine.isSignedIn {
                        Button {
                            engine.presentCreatePlaylist()
                        } label: {
                            Image(systemName: AppSymbols.plus)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(L10n.newPlaylist)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                if let update = updateChecker.availableUpdate {
                    Button {
                        updateChecker.showUpdateSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12.5, weight: .semibold))
                            Text(L10n.updateBadge(update.version))
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppColors.accent.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }

                accountFooter
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .navigationSplitViewColumnWidth(
            min: AppMetrics.sidebarMinWidth,
            ideal: AppMetrics.sidebarIdealWidth,
            max: AppMetrics.sidebarMaxWidth
        )
    }

    private func sidebarItem(_ destination: SidebarDestination) -> some View {
        let isSelected = selection == destination

        return Button {
            onSelect(destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 16.5, weight: .regular))
                    .foregroundStyle(sidebarIconColor)
                    .frame(width: 24, alignment: .center)

                Text(destination.title)
                    .font(AppTypography.sidebarItem(isSelected: isSelected))
                    .foregroundStyle(isSelected ? Color.primary : AppColors.sidebarItemText)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6.5)
            .background {
                sidebarHighlightPill(isSelected: isSelected)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func playlistSidebarItem(_ playlist: UserPlaylist) -> some View {
        let destination = SidebarDestination.playlist(id: playlist.id, title: playlist.title)
        let isSelected = selection == destination
        let resolvedCover = engine.cache.resolvedPlaylistArtwork(
            for: playlist.id,
            remoteArtwork: playlist.artworkURL,
            tracks: engine.cache.collection(for: playlist.id)?.tracks ?? []
        )

        return Button {
            onSelect(destination)
        } label: {
            HStack(spacing: 10) {
                if !resolvedCover.isEmpty {
                    ArtworkView(urlString: resolvedCover, size: 22, cornerRadius: 5)
                } else {
                    Image(systemName: AppSymbols.playlist)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(sidebarIconColor)
                        .frame(width: 24, alignment: .center)
                }

                Text(playlist.title)
                    .font(AppTypography.sidebarItem(isSelected: isSelected))
                    .foregroundStyle(isSelected ? Color.primary : AppColors.sidebarItemText)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                sidebarHighlightPill(isSelected: isSelected)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                engine.presentEditPlaylist(
                    playlistId: playlist.id,
                    title: playlist.title,
                    description: ""
                )
            } label: {
                Label(L10n.editPlaylistEllipsis, systemImage: AppSymbols.pencil)
            }

            Divider()

            Button(role: .destructive) {
                playlistToDelete = playlist
            } label: {
                Label(L10n.deletePlaylist, systemImage: AppSymbols.trash)
            }
        }
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func sidebarHighlightPill(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.sidebarActivePill)
                .matchedGeometryEffect(id: "sidebarActivePill", in: sidebarHighlightNamespace)
        }
    }

    private var accountFooter: some View {
        Button {
            engine.openSignIn()
        } label: {
            HStack(spacing: 9) {
                if engine.isSignedIn, !engine.playerState.accountAvatarURL.isEmpty {
                    ArtworkView(
                        urlString: engine.playerState.accountAvatarURL,
                        size: 26,
                        cornerRadius: 13,
                        isCircular: true
                    )
                } else {
                    ZStack {
                        Circle()
                            .fill(AppColors.avatarPlaceholderFill)
                            .frame(width: 26, height: 26)
                        Image(systemName: AppSymbols.person)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(
                    engine.isSignedIn
                        ? (engine.playerState.accountName.isEmpty ? L10n.account : engine.playerState.accountName)
                        : L10n.signIn
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.sidebarItemText)
                .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
