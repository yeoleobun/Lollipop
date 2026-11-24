(function () {
  'use strict';
  if (window.__lollipopInitialized) return;

  const Internal = window.__lollipopInternal;
  const { CONSTANTS, bestThumbnail, runsText } = Internal;
  const { BROWSE_PREFIX } = CONSTANTS;

  function inferKind(navEndpoint, videoId, browseId) {
    if (videoId) return 'song';
    const pageType =
      navEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig
        ?.pageType || '';
    if (pageType.includes('ALBUM')) return 'album';
    if (pageType.includes('PLAYLIST')) return 'playlist';
    if (pageType.includes('ARTIST')) return 'artist';
    if (browseId) {
      if (browseId.startsWith(BROWSE_PREFIX.ALBUM) || browseId.startsWith(BROWSE_PREFIX.ALBUM_PLAYLIST)) {
        return 'album';
      }
      if (browseId.startsWith(BROWSE_PREFIX.PLAYLIST_VL) || browseId.startsWith(BROWSE_PREFIX.RADIO)) {
        return 'playlist';
      }
      if (browseId.startsWith(BROWSE_PREFIX.ARTIST)) return 'artist';
    }
    return 'unknown';
  }

  function extractArtistAlbumInfo(runArrays, menuRenderer) {
    let artistBrowseId = null;
    let artistName = null;
    let albumBrowseId = null;
    let albumName = null;

    if (Array.isArray(runArrays)) {
      for (const runs of runArrays) {
        if (!Array.isArray(runs)) continue;
        for (const run of runs) {
          const bid = run?.navigationEndpoint?.browseEndpoint?.browseId;
          if (!bid) continue;
          if (!artistBrowseId && bid.startsWith(BROWSE_PREFIX.ARTIST)) {
            artistBrowseId = bid;
            artistName = (run.text || '').trim() || null;
          } else if (
            !albumBrowseId &&
            (bid.startsWith(BROWSE_PREFIX.ALBUM) || bid.startsWith(BROWSE_PREFIX.ALBUM_PLAYLIST))
          ) {
            albumBrowseId = bid;
            albumName = (run.text || '').trim() || null;
          }
        }
      }
    }

    const menuItems = menuRenderer?.items || [];
    for (const mi of menuItems) {
      const bid = mi?.menuNavigationItemRenderer?.navigationEndpoint?.browseEndpoint?.browseId;
      if (!bid) continue;
      if (!artistBrowseId && bid.startsWith(BROWSE_PREFIX.ARTIST)) {
        artistBrowseId = bid;
      } else if (
        !albumBrowseId &&
        (bid.startsWith(BROWSE_PREFIX.ALBUM) || bid.startsWith(BROWSE_PREFIX.ALBUM_PLAYLIST))
      ) {
        albumBrowseId = bid;
      }
    }

    return { artistBrowseId, artistName, albumBrowseId, albumName };
  }

  function parseTwoRowItem(r) {
    if (!r) return null;
    const title = runsText(r.title);
    if (!title) return null;
    const subtitle = runsText(r.subtitle);
    const artworkURL = bestThumbnail(r.thumbnailRenderer?.musicThumbnailRenderer?.thumbnail?.thumbnails);
    const nav = r.navigationEndpoint || {};
    const overlayNav =
      r.thumbnailOverlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer
        ?.playNavigationEndpoint;
    const watch = nav.watchEndpoint || overlayNav?.watchEndpoint;
    const watchPlaylist = nav.watchPlaylistEndpoint || overlayNav?.watchPlaylistEndpoint;
    const browseId = nav.browseEndpoint?.browseId || null;
    const videoId = watch?.videoId || null;
    const playlistId = watch?.playlistId || watchPlaylist?.playlistId || null;
    const kind = inferKind(nav, videoId, browseId);
    const id = videoId || browseId || playlistId || `${title}-${subtitle}`;
    const linked = extractArtistAlbumInfo([r.title?.runs, r.subtitle?.runs], r.menu?.menuRenderer);

    return {
      id,
      title,
      subtitle,
      artworkURL,
      kind,
      videoId,
      browseId,
      browseParams: nav.browseEndpoint?.params || null,
      playlistId,
      durationText: null,
      artistName: linked.artistName,
      albumTitle: linked.albumName,
      artistBrowseId: linked.artistBrowseId || (kind === 'artist' ? browseId : null),
      albumBrowseId: linked.albumBrowseId || (kind === 'album' ? browseId : null),
      accentColorHex: null,
      iconType: null,
      isExplicit: !!(
        r.subtitleBadges &&
        r.subtitleBadges.some(b => b?.musicInlineBadgeRenderer?.icon?.iconType === 'MUSIC_EXPLICIT_BADGE')
      )
    };
  }

  function argbIntToHex(colorInt) {
    if (typeof colorInt !== 'number' || !Number.isFinite(colorInt)) return null;
    const hex = (colorInt >>> 0).toString(16).padStart(8, '0');
    return `#${hex.slice(2).toUpperCase()}`;
  }

  function parseNavigationButton(r) {
    if (!r) return null;
    const title = runsText(r.buttonText);
    if (!title) return null;
    const browseEp = r.clickCommand?.browseEndpoint || {};
    const browseId = browseEp.browseId || null;
    const browseParams = browseEp.params || null;
    const accentColorHex = argbIntToHex(r.solid?.leftStripeColor);
    const iconType = r.iconStyle?.icon?.iconType || null;
    const id = [browseId, browseParams, title].filter(Boolean).join(':') || `nav-${title}`;

    return {
      id,
      title,
      subtitle: '',
      artworkURL: '',
      kind: 'category',
      videoId: null,
      browseId,
      browseParams,
      playlistId: null,
      durationText: null,
      artistName: null,
      albumTitle: null,
      artistBrowseId: null,
      albumBrowseId: null,
      accentColorHex,
      iconType,
      isExplicit: false
    };
  }

  function parseResponsiveListItem(r, fallbackArtwork) {
    if (!r) return null;
    const cols = r.flexColumns || [];
    const col0 = cols[0]?.musicResponsiveListItemFlexColumnRenderer?.text;
    const col1 = cols[1]?.musicResponsiveListItemFlexColumnRenderer?.text;
    const col2 = cols[2]?.musicResponsiveListItemFlexColumnRenderer?.text;

    const title = runsText(col0);
    if (!title) return null;

    let subtitle = runsText(col1);
    let albumTitle = runsText(col2) || null;
    let durationText = null;

    const fixedCols = r.fixedColumns || [];
    if (fixedCols.length > 0) {
      const dur = runsText(fixedCols[0]?.musicResponsiveListItemFixedColumnRenderer?.text);
      if (dur && /\d:\d\d/.test(dur)) durationText = dur;
    }
    if (!durationText && subtitle) {
      const parts = subtitle.split(' • ');
      const last = parts[parts.length - 1];
      if (last && /^\d+:\d{2}$/.test(last.trim())) {
        durationText = last.trim();
        subtitle = parts.slice(0, -1).join(' • ');
      }
    }

    const playEndpoint =
      r.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint ||
      col0?.runs?.[0]?.navigationEndpoint ||
      r.navigationEndpoint ||
      {};

    const watch = playEndpoint.watchEndpoint || {};
    const browse = r.navigationEndpoint?.browseEndpoint || col0?.runs?.[0]?.navigationEndpoint?.browseEndpoint || {};

    const videoId = r.playlistItemData?.videoId || watch.videoId || null;
    let setVideoId = r.playlistItemData?.playlistSetVideoId || null;
    if (!setVideoId && Array.isArray(r.menu?.menuRenderer?.items)) {
      for (const mi of r.menu.menuRenderer.items) {
        const actions = mi?.menuServiceItemRenderer?.serviceEndpoint?.playlistEditEndpoint?.actions || [];
        const rem = actions.find(a => a.action === 'ACTION_REMOVE_VIDEO' && a.setVideoId);
        if (rem) {
          setVideoId = rem.setVideoId;
          break;
        }
      }
    }
    const playlistId =
      watch.playlistId ||
      r.menu?.menuRenderer?.items?.find(i => i.menuNavigationItemRenderer?.navigationEndpoint?.watchPlaylistEndpoint)
        ?.menuNavigationItemRenderer?.navigationEndpoint?.watchPlaylistEndpoint?.playlistId ||
      null;
    const browseId = browse.browseId || null;
    const kind = inferKind(r.navigationEndpoint || playEndpoint, videoId, browseId);

    const linked = extractArtistAlbumInfo(
      cols.map(c => c?.musicResponsiveListItemFlexColumnRenderer?.text?.runs),
      r.menu?.menuRenderer
    );
    const artistBrowseId = linked.artistBrowseId;
    const artistName = linked.artistName;
    const albumBrowseId = linked.albumBrowseId;
    // Prefer the true album run over play-count columns (e.g. Artist Top Songs puts play count in col2)
    if (linked.albumName) {
      albumTitle = linked.albumName;
    } else if (albumTitle && /播放次数|plays|views/i.test(albumTitle)) {
      albumTitle = null;
    }

    const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails;
    const artworkURL = bestThumbnail(thumbs) || fallbackArtwork || '';
    const id = videoId || browseId || `${title}-${subtitle}-${Math.random().toString(36).slice(2, 7)}`;

    return {
      id,
      title,
      subtitle,
      artworkURL,
      kind,
      videoId,
      browseId,
      playlistId,
      durationText,
      artistName,
      albumTitle,
      artistBrowseId,
      albumBrowseId,
      setVideoId,
      isExplicit: !!(
        r.badges && r.badges.some(b => b?.musicInlineBadgeRenderer?.icon?.iconType === 'MUSIC_EXPLICIT_BADGE')
      )
    };
  }

  function extractSectionsFromContents(contents, sectionOffset = 0) {
    const sections = [];
    if (!Array.isArray(contents)) return sections;

    for (let idx = 0; idx < contents.length; idx++) {
      const entry = contents[idx];
      const sectionIdx = sectionOffset + idx;

      // Unwrap itemSectionRenderer if present
      if (entry.itemSectionRenderer && Array.isArray(entry.itemSectionRenderer.contents)) {
        const nested = extractSectionsFromContents(entry.itemSectionRenderer.contents, sectionIdx * 100);
        sections.push(...nested);
        continue;
      }

      // 1. Carousel shelf
      const carousel = entry.musicCarouselShelfRenderer;
      if (carousel) {
        const header = carousel.header?.musicCarouselShelfBasicHeaderRenderer;
        const title = runsText(header?.title) || 'Featured';
        const subtitle = runsText(header?.strapline) || null;
        const moreBtn = header?.moreContentButton?.buttonRenderer;
        const moreNav = moreBtn?.navigationEndpoint || {};
        const moreBrowseId = moreNav.browseEndpoint?.browseId || null;
        const moreBrowseParams = moreNav.browseEndpoint?.params || null;
        const playAllVideoId = moreNav.watchEndpoint?.videoId || null;
        const playAllPlaylistId =
          moreNav.watchEndpoint?.playlistId || moreNav.watchPlaylistEndpoint?.playlistId || null;
        const playAllParams =
          moreNav.watchEndpoint?.params || moreNav.watchPlaylistEndpoint?.params || null;
        const moreButtonTitle = runsText(moreBtn?.text) || null;

        const rawItems = carousel.contents || [];
        const items = [];
        let hasListItems = false;
        let hasNavButtons = false;

        for (const c of rawItems) {
          if (c.musicTwoRowItemRenderer) {
            const parsed = parseTwoRowItem(c.musicTwoRowItemRenderer);
            if (parsed) items.push(parsed);
          } else if (c.musicResponsiveListItemRenderer) {
            hasListItems = true;
            const parsed = parseResponsiveListItem(c.musicResponsiveListItemRenderer);
            if (parsed) items.push(parsed);
          } else if (c.musicNavigationButtonRenderer) {
            hasNavButtons = true;
            const parsed = parseNavigationButton(c.musicNavigationButtonRenderer);
            if (parsed) items.push(parsed);
          }
        }
        if (items.length > 0) {
          const layout = hasNavButtons ? 'moodGrid' : hasListItems ? 'quickPicks' : 'carousel';
          sections.push({
            id: `carousel-${sectionIdx}-${title}`,
            title,
            subtitle,
            layout,
            moreBrowseId,
            moreBrowseParams,
            moreButtonTitle,
            playAllVideoId,
            playAllPlaylistId,
            playAllParams,
            items
          });
        }
        continue;
      }

      // 2. Music Shelf (Search results, Library lists, etc.)
      const shelf = entry.musicShelfRenderer;
      if (shelf) {
        const title = runsText(shelf.title) || 'Tracks';
        const items = [];
        for (const c of shelf.contents || []) {
          if (c.musicResponsiveListItemRenderer) {
            const parsed = parseResponsiveListItem(c.musicResponsiveListItemRenderer);
            if (parsed) items.push(parsed);
          }
        }
        if (items.length > 0) {
          sections.push({
            id: `shelf-${sectionIdx}-${title}`,
            title,
            subtitle: null,
            layout: 'list',
            items
          });
        }
        continue;
      }

      // 3. Top Result Card Shelf (Search)
      const cardShelf = entry.musicCardShelfRenderer;
      if (cardShelf) {
        const title = runsText(cardShelf.header?.musicCardShelfHeaderBasicRenderer?.title) || 'Top Result';
        const mainTitle = runsText(cardShelf.title);
        const mainSub = runsText(cardShelf.subtitle);
        const artworkURL = bestThumbnail(cardShelf.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails);
        const onTap = cardShelf.onTap || {};
        const videoId =
          onTap.watchEndpoint?.videoId ||
          cardShelf.buttons?.[0]?.buttonRenderer?.command?.watchEndpoint?.videoId ||
          null;
        const browseId = onTap.browseEndpoint?.browseId || null;
        const playlistId = onTap.watchEndpoint?.playlistId || onTap.watchPlaylistEndpoint?.playlistId || null;
        const items = [];
        if (mainTitle) {
          items.push({
            id: videoId || browseId || `top-${mainTitle}`,
            title: mainTitle,
            subtitle: mainSub,
            artworkURL,
            kind: inferKind(onTap, videoId, browseId),
            videoId,
            browseId,
            playlistId,
            durationText: null,
            albumTitle: null,
            isExplicit: false
          });
        }
        for (const c of cardShelf.contents || []) {
          if (c.musicResponsiveListItemRenderer) {
            const parsed = parseResponsiveListItem(c.musicResponsiveListItemRenderer);
            if (parsed) items.push(parsed);
          }
        }
        if (items.length > 0) {
          sections.push({
            id: `top-${sectionIdx}`,
            title,
            subtitle: null,
            layout: 'list',
            items
          });
        }
        continue;
      }

      // 4. Grid Renderer (Explore quick-entry cards, Moods & Genres full page, Library albums/playlists)
      const grid = entry.gridRenderer;
      if (grid) {
        const title = runsText(grid.header?.gridHeaderRenderer?.title) || '';
        const items = [];
        let hasNavButtons = false;
        let hasIcons = false;
        for (const c of grid.items || []) {
          if (c.musicTwoRowItemRenderer) {
            const parsed = parseTwoRowItem(c.musicTwoRowItemRenderer);
            if (parsed) items.push(parsed);
          } else if (c.musicNavigationButtonRenderer) {
            hasNavButtons = true;
            const parsed = parseNavigationButton(c.musicNavigationButtonRenderer);
            if (parsed) {
              if (parsed.iconType) hasIcons = true;
              items.push(parsed);
            }
          }
        }
        if (items.length > 0) {
          const layout = hasNavButtons ? (hasIcons ? 'categoryGrid' : 'moodGrid') : 'carousel';
          sections.push({
            id: `grid-${sectionIdx}-${title || 'items'}`,
            title: title || (hasNavButtons ? '' : 'Library'),
            subtitle: null,
            layout,
            items
          });
        }
      }
    }

    return sections;
  }

  function findSectionListRenderer(data) {
    if (data?.contents?.sectionListRenderer) {
      return data.contents.sectionListRenderer;
    }
    const tabs =
      data?.contents?.singleColumnBrowseResultsRenderer?.tabs ||
      data?.contents?.tabbedSearchResultsRenderer?.tabs ||
      [];
    for (const tab of tabs) {
      const tr = tab.tabRenderer;
      if (tr?.content?.sectionListRenderer) return tr.content.sectionListRenderer;
    }
    const twoCol = data?.contents?.twoColumnBrowseResultsRenderer;
    if (twoCol?.secondaryContents?.sectionListRenderer) {
      return twoCol.secondaryContents.sectionListRenderer;
    }
    if (data?.continuationContents?.sectionListContinuation) {
      return data.continuationContents.sectionListContinuation;
    }
    return null;
  }

  function findSectionListContents(data) {
    const sl = findSectionListRenderer(data);
    return Array.isArray(sl?.contents) ? sl.contents : [];
  }

  function extractBrowseChips(data) {
    const sl = findSectionListRenderer(data);
    const chipCloud =
      sl?.header?.chipCloudRenderer ||
      data?.header?.chipCloudRenderer ||
      null;
    const rawChips = chipCloud?.chips || [];
    const chips = [];
    for (const entry of rawChips) {
      const c = entry.chipCloudChipRenderer;
      if (!c) continue;
      const title = runsText(c.text);
      const navEp = c.navigationEndpoint?.browseEndpoint || {};
      const deselectEp = c.onDeselectedCommand?.browseEndpoint || {};
      if (!title || !navEp.browseId) continue;
      chips.push({
        id: navEp.params || title,
        title,
        browseId: navEp.browseId,
        params: navEp.params || null,
        isSelected: !!c.isSelected,
        deselectBrowseId: deselectEp.browseId || null,
        deselectParams: deselectEp.params || null
      });
    }
    return chips;
  }

  function extractContinuationToken(data) {
    const sl = findSectionListRenderer(data);
    if (!sl) return null;
    const conts = sl.continuations || [];
    for (const c of conts) {
      const token =
        c?.nextContinuationData?.continuation ||
        c?.reloadContinuationData?.continuation;
      if (token) return token;
    }
    const contents = Array.isArray(sl.contents) ? sl.contents : [];
    for (const entry of contents) {
      const token = entry?.continuationItemRenderer?.continuationEndpoint?.continuationCommand?.token;
      if (token) return token;
    }
    return null;
  }

  function findLyricsInObject(obj, depth) {
    if (!obj || typeof obj !== 'object' || depth > 14) return null;
    if (obj.musicDescriptionShelfRenderer) {
      const shelf = obj.musicDescriptionShelfRenderer;
      const text = runsText(shelf.description);
      const source = runsText(shelf.footer) || 'YouTube Music';
      if (text) return { lines: text.split('\n'), source };
    }
    if (obj.timedLyricsModel?.lyricsData?.timedLyricsData) {
      const td = obj.timedLyricsModel.lyricsData;
      const timedLines = td.timedLyricsData
        .map(x => ({
          text: x.lyricLine || '',
          startTime: x.cueRange?.startTimeMilliseconds ? Number(x.cueRange.startTimeMilliseconds) / 1000 : null
        }))
        .filter(x => x.text);
      if (timedLines.length > 0) {
        return {
          lines: timedLines.map(x => x.text),
          timedLines,
          source: td.sourceMessage || 'YouTube Music'
        };
      }
    }
    if (Array.isArray(obj)) {
      for (const item of obj) {
        const found = findLyricsInObject(item, depth + 1);
        if (found) return found;
      }
    } else {
      for (const key of Object.keys(obj)) {
        const found = findLyricsInObject(obj[key], depth + 1);
        if (found) return found;
      }
    }
    return null;
  }

  Internal.inferKind = inferKind;
  Internal.extractArtistAlbumInfo = extractArtistAlbumInfo;
  Internal.parseTwoRowItem = parseTwoRowItem;
  Internal.parseNavigationButton = parseNavigationButton;
  Internal.parseResponsiveListItem = parseResponsiveListItem;
  Internal.extractSectionsFromContents = extractSectionsFromContents;
  Internal.findSectionListContents = findSectionListContents;
  Internal.extractBrowseChips = extractBrowseChips;
  Internal.extractContinuationToken = extractContinuationToken;
  Internal.findLyricsInObject = findLyricsInObject;
})();
