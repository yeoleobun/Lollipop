import SwiftUI

struct MainView: View {
    @Bindable var engine: YouTubeMusicEngine
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
                selection: $selection,
                playlistToDelete: $playlistToDelete,
                onSelect: select
            )
        } detail: {
            NavigationStack(path: $navigationPath) {
                detailRootView
                    .id(selection.id)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                    .navigationDestination(for: AppRoute.self) { appRoute in
                        routeDestinationView(for: appRoute)
                    }
            }
            .animation(AppAnimations.standard, value: selection)
            .overlay(alignment: .bottom) {
                NowPlayingBar(
                    engine: engine,
                    showInspector: $showInspector,
                    inspectorTab: $inspectorTab,
                    onOpenRoute: openRoute
                )
            }
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
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
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

    private func select(_ destination: SidebarDestination) {
        withAnimation(AppAnimations.sidebarSpring) {
            navigationPath.removeAll()
            selection = destination
        }
        Task { await loadDestinationIfNeeded(destination) }
    }

    // MARK: - Detail Views

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
                        if !navigationPath.isEmpty {
                            navigationPath.removeLast()
                        }
                    }
                )
            }

        case .section(let section):
            SectionGridView(
                section: section,
                engine: engine,
                onOpenRoute: openRoute
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
                onOpenCollection: openRoute,
                onOpenSection: openSection,
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
