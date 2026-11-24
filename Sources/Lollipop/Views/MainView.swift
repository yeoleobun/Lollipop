import SwiftUI

struct MainView: View {
    @Bindable var engine: YouTubeMusicEngine
    @Bindable var updateChecker: UpdateChecker
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab

    @ViewState private var selection: SidebarDestination = .home
    @ViewState private var searchQuery: String = ""
    @ViewState private var navigationPath: [AppRoute] = []
    @ViewState private var playlistToDelete: UserPlaylist? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(
                engine: engine,
                updateChecker: updateChecker,
                selection: $selection,
                playlistToDelete: $playlistToDelete,
                onSelect: select
            )
            .toolbar(removing: .sidebarToggle)
        } detail: {
            ZStack {
                detailRootView
                    .id(selection.id)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                    .opacity(navigationPath.isEmpty ? 1 : 0)
                    .allowsHitTesting(navigationPath.isEmpty)
                    .accessibilityHidden(!navigationPath.isEmpty)

                if let currentRoute = navigationPath.last {
                    routeDestinationView(for: currentRoute)
                        .id(currentRoute)
                        .transition(.opacity.combined(with: .offset(x: 12)))
                        .safeAreaInset(edge: .top, spacing: 0) {
                            detailBackBar
                        }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                nowPlayingBar
            }
            .animation(AppAnimations.standard, value: selection)
            .animation(AppAnimations.routeSpring, value: navigationPath)
        }
        .overlay {
            if showInspector {
                FullScreenPlayerView(
                    engine: engine,
                    selectedTab: $inspectorTab,
                    onClose: {
                        withAnimation(AppAnimations.overlaySpring) {
                            showInspector = false
                        }
                    },
                    onOpenRoute: openRoute
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(AppAnimations.overlaySpring, value: showInspector)
        .background {
            // Hidden audio-only embedded player host (kept alive at 1x1 so WebKit never suspends audio)
            SharedWebViewHost(
                webView: engine.webView,
                isActiveHost: !engine.showEmbeddedPlayerSheet
            )
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $engine.showSignInSheet) {
            SignInSheet(engine: engine)
        }
        .sheet(isPresented: $engine.showEmbeddedPlayerSheet) {
            EmbeddedPlayerSheet(engine: engine)
        }
        .sheet(isPresented: $updateChecker.showUpdateSheet) {
            UpdateSheet(updater: updateChecker)
        }
        .sheet(item: $engine.playlistEditorMode) { mode in
            PlaylistEditorSheet(mode: mode, engine: engine) { browseId in
                if case .create(let initialVideoId) = mode,
                   initialVideoId == nil,
                   let browseId {
                    if let created = engine.userPlaylists.first(where: { $0.id == browseId }) {
                        select(.playlist(id: created.id, title: created.title))
                    } else {
                        select(.playlist(id: browseId, title: L10n.newPlaylist))
                    }
                }
            }
        }
        .alert(
            L10n.deletePlaylistConfirmTitle,
            isPresented: Binding(
                get: { playlistToDelete != nil },
                set: { if !$0 { playlistToDelete = nil } }
            )
        ) {
            Button(L10n.cancel, role: .cancel) {
                playlistToDelete = nil
            }
            Button(L10n.delete, role: .destructive) {
                if let target = playlistToDelete {
                    playlistToDelete = nil
                    Task {
                        let ok = await engine.deletePlaylist(playlistId: target.id)
                        if ok, case .playlist(let currentId, _) = selection, currentId == target.id {
                            select(.home)
                        }
                    }
                }
            }
        } message: {
            Text(L10n.deletePlaylistConfirmMsg)
        }
        .tint(AppColors.accent)
    }

    // MARK: - Navigation Helpers

    private func openRoute(_ route: NavigationRoute) {
        withAnimation(AppAnimations.routeSpring) {
            showInspector = false
            navigationPath.append(.collection(route))
        }
    }

    private func openSection(_ section: MusicSection) {
        withAnimation(AppAnimations.routeSpring) {
            showInspector = false
            navigationPath.append(.section(section))
        }
    }

    private func openBrowse(_ route: BrowseRoute) {
        withAnimation(AppAnimations.routeSpring) {
            showInspector = false
            navigationPath.append(.browse(route))
        }
    }

    private func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        withAnimation(AppAnimations.routeSpring) {
            _ = navigationPath.removeLast()
        }
    }

    private func select(_ destination: SidebarDestination) {
        withAnimation(AppAnimations.sidebarSpring) {
            navigationPath.removeAll()
            selection = destination
        }
        Task { await loadDestinationIfNeeded(destination) }
    }

    // MARK: - Detail Views

    private var detailBackBar: some View {
        HStack(spacing: 8) {
            Button {
                navigateBack()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: AppSymbols.chevronLeft)
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.back)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .liquidGlassCapsule(interactive: true)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: .command)
            .help(L10n.back)

            Spacer()
        }
        .padding(.horizontal, AppMetrics.pageHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 0)
    }

    private var nowPlayingBar: some View {
        NowPlayingBar(
            engine: engine,
            showInspector: $showInspector,
            inspectorTab: $inspectorTab,
            onOpenRoute: openRoute
        )
    }

    @ViewBuilder
    private func routeDestinationView(for appRoute: AppRoute) -> some View {
        switch appRoute {
        case .collection(let route):
            if YouTubeMusicConstants.isArtistBrowseId(route.browseId) {
                ArtistDetailView(
                    browseId: route.browseId,
                    fallbackName: route.title,
                    fallbackArtworkURL: route.artworkURL,
                    engine: engine,
                    onOpenRoute: openRoute,
                    onOpenSection: openSection
                )
            } else {
                CollectionDetailView(
                    browseId: route.browseId,
                    fallbackTitle: route.title,
                    fallbackArtworkURL: route.artworkURL,
                    engine: engine,
                    autoPlay: route.autoPlay,
                    autoPlayVideoId: route.autoPlayVideoId,
                    onOpenRoute: openRoute,
                    onDeletedPlaylist: {
                        navigateBack()
                    }
                )
            }

        case .section(let section):
            SectionGridView(
                section: section,
                engine: engine,
                onOpenRoute: openRoute
            )

        case .browse(let browseRoute):
            RemoteBrowseView(
                route: browseRoute,
                engine: engine,
                onOpenCollection: openRoute,
                onOpenSection: openSection,
                onOpenBrowse: openBrowse
            )
        }
    }

    @ViewBuilder
    private var detailRootView: some View {
        switch selection {
        case .home:
            BrowseView(
                title: L10n.home,
                sections: engine.homeSections,
                isLoading: engine.isLoadingHome,
                engine: engine,
                chips: engine.homeChips,
                selectedChipId: engine.selectedHomeChip?.id,
                onSelectChip: { chip in await engine.selectHomeChip(chip) },
                onOpenCollection: openRoute,
                onOpenSection: openSection,
                onOpenBrowse: openBrowse,
                hasMore: engine.homeContinuation != nil,
                isLoadingMore: engine.isLoadingMoreHome,
                onLoadMore: { await engine.loadMoreHome() },
                onRefresh: { await engine.refreshHome() }
            )

        case .explore:
            BrowseView(
                title: L10n.explore,
                sections: engine.exploreSections,
                isLoading: engine.isLoadingExplore,
                engine: engine,
                onOpenCollection: openRoute,
                onOpenSection: openSection,
                onOpenBrowse: openBrowse,
                hasMore: engine.exploreContinuation != nil,
                isLoadingMore: engine.isLoadingMoreExplore,
                onLoadMore: { await engine.loadMoreExplore() },
                onRefresh: { await engine.refreshExplore() }
            )

        case .charts:
            BrowseView(
                title: L10n.charts,
                sections: engine.chartsSections,
                isLoading: engine.isLoadingCharts,
                engine: engine,
                onOpenCollection: openRoute,
                onOpenSection: openSection,
                onOpenBrowse: openBrowse,
                onRefresh: { await engine.refreshCharts() }
            )

        case .search:
            SearchView(
                query: $searchQuery,
                engine: engine,
                onOpenCollection: openRoute
            )

        case .likedSongs:
            CollectionDetailView(
                browseId: YouTubeMusicConstants.BrowseID.likedMusicPlaylist,
                fallbackTitle: L10n.likedSongs,
                fallbackArtworkURL: "",
                engine: engine,
                onOpenRoute: openRoute
            )

        case .history:
            BrowseView(
                title: L10n.history,
                sections: engine.historySections,
                isLoading: engine.isLoadingHistory,
                engine: engine,
                onOpenCollection: openRoute,
                onOpenSection: openSection,
                onRefresh: { await engine.refreshHistory() }
            )

        case .library:
            LibraryView(
                engine: engine,
                onOpenCollection: openRoute
            )

        case .playlist(let id, let title):
            CollectionDetailView(
                browseId: id,
                fallbackTitle: title,
                fallbackArtworkURL: "",
                engine: engine,
                onOpenRoute: openRoute,
                onDeletedPlaylist: { select(.home) }
            )
        }
    }

    private func loadDestinationIfNeeded(_ destination: SidebarDestination) async {
        switch destination {
        case .home:
            if engine.homeSections.isEmpty { await engine.refreshHome() }
        case .explore:
            if engine.exploreSections.isEmpty { await engine.refreshExplore() }
        case .charts:
            if engine.chartsSections.isEmpty { await engine.refreshCharts() }
        case .history:
            if engine.historySections.isEmpty { await engine.refreshHistory() }
        case .search, .likedSongs, .library, .playlist:
            break
        }
    }
}
