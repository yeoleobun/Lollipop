import SwiftUI

struct BrowseView: View {
    let title: String
    let sections: [MusicSection]
    let isLoading: Bool
    let engine: YouTubeMusicEngine
    var chips: [BrowseChip] = []
    var selectedChipId: String? = nil
    var onSelectChip: ((BrowseChip) async -> Void)? = nil
    let onOpenCollection: (NavigationRoute) -> Void
    var onOpenSection: ((MusicSection) -> Void)? = nil
    var onOpenBrowse: ((BrowseRoute) -> Void)? = nil
    var hasMore: Bool = false
    var isLoadingMore: Bool = false
    var onLoadMore: (() async -> Void)? = nil
    let onRefresh: () async -> Void

    var body: some View {
        Group {
            if sections.isEmpty {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        if !chips.isEmpty {
                            chipBar
                        }
                    }
                    .padding(.horizontal, AppMetrics.pageHorizontalPadding)
                    .padding(.top, AppMetrics.pageTopPadding)

                    if isLoading {
                        loadingPlaceholder
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 14) {
                            header
                            if !chips.isEmpty {
                                chipBar
                            }
                        }

                        ForEach(sections) { section in
                            sectionView(section)
                                .transition(.opacity)
                        }
                        .opacity(isLoading && !sections.isEmpty ? 0.55 : 1.0)
                        .animation(AppAnimations.standard, value: sections)
                        .animation(AppAnimations.fastHover, value: isLoading)

                        if hasMore, let onLoadMore {
                            loadMoreFooter(onLoadMore: onLoadMore)
                        }
                    }
                    .pageScrollContent()
                }
            }
        }
        .pageBackground()
    }

    @Namespace private var chipSelectionNamespace

    private var chipBar: some View {
        let activeChip = chips.first(where: { $0.id == selectedChipId })

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let activeChip {
                    NativeScopeChip(
                        title: L10n.all,
                        isSelected: false,
                        namespace: chipSelectionNamespace
                    ) {
                        if let onSelectChip {
                            Task { await onSelectChip(activeChip) }
                        }
                    }
                } else {
                    NativeScopeChip(
                        title: L10n.all,
                        isSelected: true,
                        namespace: chipSelectionNamespace
                    ) {}
                }

                ForEach(chips) { chip in
                    let isSelected = chip.id == selectedChipId
                    NativeScopeChip(
                        title: chip.title,
                        isSelected: isSelected,
                        namespace: chipSelectionNamespace
                    ) {
                        if let onSelectChip {
                            Task { await onSelectChip(chip) }
                        }
                    }
                }
            }
            .padding(.trailing, 28)
            .padding(.vertical, 2)
        }
        .mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 28)
            }
        )
        .animation(AppAnimations.sidebarSpring, value: selectedChipId)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTypography.pageTitle)
                .tracking(-0.4)

            if isLoading && !sections.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 6)
            }

            Spacer()

            Button {
                Task { await onRefresh() }
            } label: {
                Image(systemName: AppSymbols.refresh)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.refresh(title))
        }
    }

    @ViewBuilder
    private func sectionView(_ section: MusicSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !section.title.isEmpty {
                let headerTap: (() -> Void)? = {
                    if let moreBrowseId = section.moreBrowseId, !moreBrowseId.isEmpty, let onOpenBrowse {
                        return {
                            onOpenBrowse(
                                BrowseRoute(
                                    browseId: moreBrowseId,
                                    params: section.moreBrowseParams,
                                    title: section.title
                                )
                            )
                        }
                    }
                    if section.layout == .categoryGrid || section.layout == .moodGrid {
                        return nil
                    }
                    return onOpenSection.map { callback in { callback(section) } }
                }()

                let playAllAction: (() -> Void)? = {
                    let fallbackFirstTrack = section.items.first(where: { $0.videoId != nil })
                    if let vid = section.playAllVideoId, !vid.isEmpty {
                        let resolvedPlaylistId =
                            section.playAllPlaylistId
                            ?? fallbackFirstTrack?.playlistId
                            ?? (YouTubeMusicConstants.Prefix.trackRadio + vid)
                        return {
                            engine.play(
                                videoId: vid,
                                playlistId: resolvedPlaylistId,
                                params: section.playAllParams
                            )
                        }
                    }
                    if let pid = section.playAllPlaylistId, !pid.isEmpty {
                        let resolvedVideoId = fallbackFirstTrack?.videoId ?? ""
                        return {
                            engine.play(
                                videoId: resolvedVideoId,
                                playlistId: pid,
                                params: section.playAllParams
                            )
                        }
                    }
                    return nil
                }()

                SectionHeaderView(
                    title: section.title,
                    subtitle: section.subtitle,
                    onTap: headerTap,
                    onPlayAll: playAllAction
                )
            }

            switch section.layout {
            case .carousel:
                HorizontalCarouselView(
                    items: section.items,
                    onTap: { item in
                        handleItemTap(item)
                    },
                    onPlay: { engine.play(item: $0) },
                    onOpenRoute: onOpenCollection
                )

            case .quickPicks:
                quickPicksGrid(items: section.items)

            case .list:
                VStack(spacing: 2) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, item in
                        TrackRowView(
                            item: item,
                            index: idx,
                            showArtwork: true,
                            isCurrentTrack: item.videoId != nil && item.videoId == engine.playerState.videoId,
                            isPlaying: engine.playerState.isPlaying,
                            engine: engine,
                            onTap: {
                                MusicItemNavigator.handleRowTap(item, engine: engine, onOpenRoute: onOpenCollection)
                            },
                            onOpenRoute: onOpenCollection
                        )
                    }
                }

            case .categoryGrid:
                categoryCardsGrid(items: section.items)

            case .moodGrid:
                moodTilesGrid(items: section.items)
            }
        }
    }

    private func handleItemTap(_ item: MusicItem) {
        if item.kind == .category, let browseId = item.browseId, let onOpenBrowse {
            onOpenBrowse(
                BrowseRoute(browseId: browseId, params: item.browseParams, title: item.title)
            )
            return
        }
        MusicItemNavigator.handleCardTap(item, engine: engine, onOpenRoute: onOpenCollection)
    }

    private func categoryCardsGrid(items: [MusicItem]) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 160), spacing: 14),
            count: min(3, max(1, items.count))
        )
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { item in
                NativeCategoryCard(
                    title: item.title,
                    symbol: symbolForCategoryIcon(item.iconType, browseId: item.browseId),
                    onTap: { handleItemTap(item) }
                )
            }
        }
    }

    private func moodTilesGrid(items: [MusicItem]) -> some View {
        let rowCount = min(4, max(1, items.count))
        let rows = Array(repeating: GridItem(.fixed(42), spacing: 10), count: rowCount)
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 10) {
                ForEach(items) { item in
                    NativeMoodTile(
                        title: item.title,
                        accentColor: colorFromHex(item.accentColorHex) ?? AppColors.accent,
                        onTap: { handleItemTap(item) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func loadMoreFooter(onLoadMore: @escaping () async -> Void) -> some View {
        HStack {
            Spacer()
            if isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.loadingMore)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            } else {
                Button {
                    Task { await onLoadMore() }
                } label: {
                    Text(L10n.loadMore)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
                .onAppear {
                    Task { await onLoadMore() }
                }
            }
            Spacer()
        }
    }

    private func symbolForCategoryIcon(_ iconType: String?, browseId: String?) -> String {
        switch iconType {
        case "MUSIC_NEW_RELEASE": return AppSymbols.newRelease
        case "TRENDING_UP": return AppSymbols.charts
        case "MOOD": return AppSymbols.moodFace
        case "PODCASTS": return AppSymbols.podcasts
        default:
            if browseId == YouTubeMusicConstants.BrowseID.newReleases { return AppSymbols.newRelease }
            if browseId == YouTubeMusicConstants.BrowseID.charts { return AppSymbols.charts }
            if browseId == YouTubeMusicConstants.BrowseID.moodsAndGenres { return AppSymbols.moodFace }
            return AppSymbols.sparkles
        }
    }

    private func colorFromHex(_ hex: String?) -> Color? {
        guard let hex else { return nil }
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private func quickPicksGrid(items: [MusicItem]) -> some View {
        let rows = Array(
            repeating: GridItem(.fixed(AppMetrics.quickPicksRowHeight), spacing: 6),
            count: min(4, max(1, items.count))
        )
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 16) {
                ForEach(items) { item in
                    TrackRowView(
                        item: item,
                        showArtwork: true,
                        isCurrentTrack: item.videoId != nil && item.videoId == engine.playerState.videoId,
                        isPlaying: engine.playerState.isPlaying,
                        engine: engine,
                        onTap: {
                            MusicItemNavigator.handleRowTap(item, engine: engine, onOpenRoute: onOpenCollection)
                        },
                        onOpenRoute: onOpenCollection
                    )
                    .frame(width: AppMetrics.quickPicksWidth)
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
            Text(engine.isEngineLoaded ? L10n.loading(title) : L10n.startingAudioEngine)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .pageCenteredState()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: AppSymbols.emptyBrowse)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)

            Text(L10n.nothingLoadedYet)
                .font(.system(size: 16, weight: .semibold))

            if let err = engine.errorMessage {
                Text(err)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 12) {
                Button(L10n.reload) {
                    Task { await onRefresh() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                if !engine.playerState.isSignedIn {
                    Button(L10n.signIn) {
                        engine.openSignIn()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .pageCenteredState()
    }
}

/// Dynamic sub-browse page for Explore categories, Moods & Genres, New Releases, and section "More" pages.
struct RemoteBrowseView: View {
    let route: BrowseRoute
    let engine: YouTubeMusicEngine
    let onOpenCollection: (NavigationRoute) -> Void
    let onOpenSection: (MusicSection) -> Void
    let onOpenBrowse: (BrowseRoute) -> Void

    @ViewState private var sections: [MusicSection] = []
    @ViewState private var chips: [BrowseChip] = []
    @ViewState private var selectedChipId: String? = nil
    @ViewState private var continuation: String? = nil
    @ViewState private var isLoading = false
    @ViewState private var isLoadingMore = false

    var body: some View {
        BrowseView(
            title: route.title,
            sections: sections,
            isLoading: isLoading,
            engine: engine,
            chips: chips,
            selectedChipId: selectedChipId,
            onSelectChip: { chip in
                await selectChip(chip)
            },
            onOpenCollection: onOpenCollection,
            onOpenSection: onOpenSection,
            onOpenBrowse: onOpenBrowse,
            hasMore: continuation != nil,
            isLoadingMore: isLoadingMore,
            onLoadMore: {
                await loadMore()
            },
            onRefresh: {
                await load(browseId: route.browseId, params: route.params, forceRefresh: true)
            }
        )
        .task(id: route) {
            await load(browseId: route.browseId, params: route.params, forceRefresh: false)
        }
    }

    private func load(browseId: String, params: String?, forceRefresh: Bool = false) async {
        if !forceRefresh, let cached = engine.cache.browsePage(browseId: browseId, params: params) {
            sections = cached.sections
            if !cached.chips.isEmpty { chips = cached.chips }
            continuation = cached.continuation
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await engine.cache.loadBrowsePage(
                browseId: browseId,
                params: params,
                forceRefresh: forceRefresh
            ) {
                try await engine.fetchBrowsePage(
                    browseId: browseId,
                    params: params,
                    maxContinuationPages: 1
                )
            }
            sections = page.sections
            if !page.chips.isEmpty {
                chips = page.chips
            }
            continuation = page.continuation
        } catch {
            // Keep existing state on transient error
        }
    }

    private func selectChip(_ chip: BrowseChip) async {
        let isDeselecting = selectedChipId == chip.id || chip.isSelected
        if isDeselecting {
            selectedChipId = nil
            await load(
                browseId: chip.deselectBrowseId ?? route.browseId,
                params: chip.deselectParams ?? route.params,
                forceRefresh: false
            )
        } else {
            selectedChipId = chip.id
            await load(browseId: chip.browseId, params: chip.params, forceRefresh: false)
        }
    }

    private func loadMore() async {
        guard !isLoadingMore, let token = continuation, !token.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let payload = try await engine.fetchBrowseContinuation(
                continuation: token,
                sectionOffset: (sections.count + 1) * 10
            )
            if !payload.sections.isEmpty {
                sections.append(contentsOf: payload.sections)
                engine.cache.index(sections: payload.sections)
                let activeBrowseId = chips.first(where: { $0.id == selectedChipId })?.browseId ?? route.browseId
                let activeParams = chips.first(where: { $0.id == selectedChipId })?.params ?? route.params
                engine.cache.storeBrowsePage(
                    BrowsePagePayload(chips: chips, sections: sections, continuation: payload.continuation),
                    browseId: activeBrowseId,
                    params: activeParams
                )
            }
            continuation = payload.continuation
        } catch {
            continuation = nil
        }
    }
}

// MARK: - Native macOS Scope Bar & Category Controls

private struct NativeScopeChip: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @ViewState private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.primary : (isHovered ? Color.primary : Color.secondary))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.10))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            )
                            .matchedGeometryEffect(id: "activeScopeChip", in: namespace)
                    } else if isHovered {
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimations.fastHover) {
                isHovered = hovering
            }
        }
    }
}

private struct NativeCategoryCard: View {
    let title: String
    let symbol: String
    let onTap: () -> Void

    @ViewState private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.accent.opacity(0.10))
                    )

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: AppSymbols.chevronRight)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isHovered ? .secondary : .tertiary)
                    .offset(x: isHovered ? 2 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.075 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 0.6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimations.fastHover) {
                isHovered = hovering
            }
        }
    }
}

private struct NativeMoodTile: View {
    let title: String
    let accentColor: Color
    let onTap: () -> Void

    @ViewState private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .frame(width: 170, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimations.fastHover) {
                isHovered = hovering
            }
        }
    }
}
