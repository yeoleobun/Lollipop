(function () {
  'use strict';
  if (window.__lollipopInitialized) return;

  const Internal = window.__lollipopInternal;
  const {
    CONSTANTS,
    SELECTORS,
    innertube,
    upgradeArtwork,
    bestThumbnail,
    runsText,
    extractArtistAlbumInfo,
    parseTwoRowItem,
    parseResponsiveListItem,
    extractSectionsFromContents,
    findSectionListContents,
    findLyricsInObject,
    getMoviePlayer,
    startStateTicker,
    playerControls
  } = Internal;
  const { BROWSE_PREFIX, BROWSE_ID } = CONSTANTS;

  window.__lollipop = {
    ...playerControls,

    async fetchBrowse(browseId) {
      const data = await innertube('browse', { browseId });
      const contents = findSectionListContents(data);
      return JSON.stringify(extractSectionsFromContents(contents));
    },

    async fetchArtist(browseId) {
      const data = await innertube('browse', { browseId });
      const header =
        data?.header?.musicImmersiveHeaderRenderer ||
        data?.header?.musicVisualHeaderRenderer ||
        {};
      const name = runsText(header.title) || 'Artist';
      const description = runsText(header.description);
      const subscribers =
        runsText(header.subscriptionButton?.subscribeButtonRenderer?.subscriberCountText) ||
        runsText(header.monthlyListenerCount) ||
        '';
      const artworkURL = bestThumbnail(
        header.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails ||
          header.foregroundThumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails
      );
      const contents = findSectionListContents(data);
      const sections = extractSectionsFromContents(contents);
      return JSON.stringify({
        id: browseId,
        name,
        subscribers,
        description,
        artworkURL,
        sections
      });
    },

    async fetchCollection(rawBrowseId) {
      let browseId = (rawBrowseId || '').trim();
      if (/^(OLAK|PL|RDCLAK|LM)/.test(browseId)) {
        browseId = BROWSE_PREFIX.PLAYLIST_VL + browseId;
      }
      const data = await innertube('browse', { browseId });

      // Header extraction (supports both classic and responsive two-column layouts)
      let title = '';
      let subtitle = '';
      let description = '';
      let artworkURL = '';
      let playlistId = browseId.startsWith(BROWSE_PREFIX.PLAYLIST_VL) ? browseId.slice(2) : null;
      let artistName = null;
      let artistBrowseId = null;

      const twoColHeader =
        data?.contents?.twoColumnBrowseResultsRenderer?.tabs?.[0]?.tabRenderer?.content
          ?.sectionListRenderer?.contents?.[0]?.musicResponsiveHeaderRenderer;
      const classicHeader =
        data?.header?.musicDetailHeaderRenderer ||
        data?.header?.musicEditablePlaylistDetailHeaderRenderer?.header?.musicDetailHeaderRenderer ||
        data?.header?.musicImmersiveHeaderRenderer;

      if (twoColHeader) {
        title = runsText(twoColHeader.title);
        subtitle = [
          runsText(twoColHeader.straplineTextOne),
          runsText(twoColHeader.subtitle),
          runsText(twoColHeader.secondSubtitle)
        ]
          .filter(Boolean)
          .join(' • ');
        description = runsText(twoColHeader.description?.musicDescriptionShelfRenderer?.description);
        artworkURL = bestThumbnail(twoColHeader.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails);
        const headerLinked = extractArtistAlbumInfo(
          [twoColHeader.straplineTextOne?.runs, twoColHeader.subtitle?.runs],
          null
        );
        artistName = headerLinked.artistName || runsText(twoColHeader.straplineTextOne) || null;
        artistBrowseId = headerLinked.artistBrowseId;
        const playBtn = twoColHeader.buttons?.find(b => b.musicPlayButtonRenderer)?.musicPlayButtonRenderer;
        const wp = playBtn?.playNavigationEndpoint?.watchPlaylistEndpoint || playBtn?.playNavigationEndpoint?.watchEndpoint;
        if (wp?.playlistId) playlistId = wp.playlistId;
      } else if (classicHeader) {
        title = runsText(classicHeader.title);
        subtitle = [runsText(classicHeader.subtitle), runsText(classicHeader.secondSubtitle)]
          .filter(Boolean)
          .join(' • ');
        description = runsText(classicHeader.description);
        artworkURL = bestThumbnail(
          classicHeader.thumbnail?.croppedSquareThumbnailRenderer?.thumbnail?.thumbnails ||
            classicHeader.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails
        );
        const headerLinked = extractArtistAlbumInfo([classicHeader.subtitle?.runs], null);
        artistName = headerLinked.artistName;
        artistBrowseId = headerLinked.artistBrowseId;
      }

      const isAlbum = browseId.startsWith(BROWSE_PREFIX.ALBUM);
      const contents = findSectionListContents(data);
      const tracks = [];
      const collectShelf = shelf => {
        if (!shelf) return;
        if (!playlistId && shelf.playlistId) playlistId = shelf.playlistId;
        for (const c of shelf.contents || []) {
          if (c.musicResponsiveListItemRenderer) {
            const item = parseResponsiveListItem(c.musicResponsiveListItemRenderer, artworkURL);
            if (item) {
              if (!item.playlistId && playlistId) item.playlistId = playlistId;
              if (isAlbum) {
                if (!item.albumBrowseId) item.albumBrowseId = browseId;
                if (!item.albumTitle && title) item.albumTitle = title;
                if (!item.artistName && artistName) item.artistName = artistName;
                if (!item.artistBrowseId && artistBrowseId) item.artistBrowseId = artistBrowseId;
              }
              tracks.push(item);
            }
          }
        }
      };

      for (const entry of contents) {
        collectShelf(entry.musicPlaylistShelfRenderer || entry.musicShelfRenderer);
        if (entry.itemSectionRenderer && Array.isArray(entry.itemSectionRenderer.contents)) {
          for (const sub of entry.itemSectionRenderer.contents) {
            collectShelf(sub.musicPlaylistShelfRenderer || sub.musicShelfRenderer);
          }
        }
      }

      const isEditable = !!(
        data?.header?.musicEditablePlaylistDetailHeaderRenderer ||
        (twoColHeader &&
          Array.isArray(twoColHeader.buttons) &&
          twoColHeader.buttons.some(
            b =>
              b?.buttonRenderer?.navigationEndpoint?.playlistEditorEndpoint ||
              b?.buttonRenderer?.icon?.iconType === 'EDIT'
          )) ||
        tracks.some(t => !!t.setVideoId)
      );

      return JSON.stringify({
        id: browseId,
        title: title || 'Collection',
        subtitle,
        description,
        artworkURL,
        playlistId,
        artistName,
        artistBrowseId,
        isEditable,
        tracks
      });
    },

    async fetchSearch(query, params) {
      const body = { query };
      if (params) body.params = params;
      const data = await innertube('search', body);
      const contents = findSectionListContents(data);
      return JSON.stringify(extractSectionsFromContents(contents));
    },

    async fetchAccountProfile() {
      let name = '';
      let email = '';
      let avatarURL = '';

      try {
        const data = await innertube('account/account_menu', {});
        const header =
          data?.actions?.[0]?.openPopupAction?.popup?.multiPageMenuRenderer?.header
            ?.activeAccountHeaderRenderer;
        if (header) {
          name = runsText(header.accountName);
          email = runsText(header.email) || runsText(header.channelHandle);
          avatarURL = bestThumbnail(header.accountPhoto?.thumbnails);
        }
      } catch (_) {}

      if (!avatarURL) {
        const img = document.querySelector(SELECTORS.AVATAR_IMAGE);
        if (img && img.src) avatarURL = upgradeArtwork(img.src);
      }

      return JSON.stringify({ name, email, avatarURL });
    },

    async fetchUserPlaylists() {
      const playlists = [];
      const seen = new Set();

      function addPlaylist(id, title, subtitle, artworkURL) {
        if (
          !id ||
          !title ||
          id === BROWSE_ID.LIKED_MUSIC_VL ||
          id === BROWSE_ID.LIKED_MUSIC_SHORT ||
          seen.has(id)
        ) {
          return;
        }
        if (id.startsWith(BROWSE_PREFIX.ARTIST) || id.startsWith(BROWSE_PREFIX.ALBUM)) return;
        const normalizedId =
          id.startsWith('PL') || id.startsWith(BROWSE_PREFIX.RADIO)
            ? `${BROWSE_PREFIX.PLAYLIST_VL}${id}`
            : id;
        if (!normalizedId.startsWith(BROWSE_PREFIX.PLAYLIST_VL) || seen.has(normalizedId)) return;
        seen.add(normalizedId);
        playlists.push({
          id: normalizedId,
          title,
          subtitle: subtitle || '',
          artworkURL: artworkURL || ''
        });
      }

      function collectFromContents(contents) {
        if (!Array.isArray(contents)) return;
        for (const entry of contents) {
          if (entry.itemSectionRenderer && Array.isArray(entry.itemSectionRenderer.contents)) {
            collectFromContents(entry.itemSectionRenderer.contents);
          }
          const rawItems =
            entry.gridRenderer?.items ||
            entry.musicShelfRenderer?.contents ||
            entry.musicCarouselShelfRenderer?.contents ||
            [];
          for (const c of rawItems) {
            if (c.musicTwoRowItemRenderer) {
              const parsed = parseTwoRowItem(c.musicTwoRowItemRenderer);
              if (parsed) {
                const bid = parsed.browseId || (parsed.playlistId ? `VL${parsed.playlistId}` : null);
                addPlaylist(bid, parsed.title, parsed.subtitle, parsed.artworkURL);
              }
            } else if (c.musicResponsiveListItemRenderer) {
              const parsed = parseResponsiveListItem(c.musicResponsiveListItemRenderer);
              if (parsed) {
                const bid = parsed.browseId || (parsed.playlistId ? `VL${parsed.playlistId}` : null);
                addPlaylist(bid, parsed.title, parsed.subtitle, parsed.artworkURL);
              }
            }
          }
        }
      }

      try {
        const data = await innertube('browse', { browseId: BROWSE_ID.LIKED_PLAYLISTS });
        collectFromContents(findSectionListContents(data));
      } catch (_) {}

      if (playlists.length === 0) {
        try {
          const data = await innertube('browse', { browseId: BROWSE_ID.LIBRARY_LANDING });
          collectFromContents(findSectionListContents(data));
        } catch (_) {}
      }

      return JSON.stringify(playlists);
    },

    async createPlaylist(title, description, privacyStatus, videoIds) {
      const body = {
        title: title || 'New Playlist',
        description: description || '',
        privacyStatus: privacyStatus || 'PRIVATE'
      };
      if (Array.isArray(videoIds) && videoIds.length > 0) {
        body.videoIds = videoIds;
      }
      const data = await innertube('playlist/create', body);
      const playlistId = data?.playlistId || '';
      return JSON.stringify({
        playlistId,
        browseId: playlistId
          ? playlistId.startsWith(BROWSE_PREFIX.PLAYLIST_VL)
            ? playlistId
            : `${BROWSE_PREFIX.PLAYLIST_VL}${playlistId}`
          : ''
      });
    },

    async editPlaylistMetadata(rawPlaylistId, title, description, privacyStatus) {
      const playlistId = (rawPlaylistId || '').replace(/^VL/, '');
      const actions = [];
      if (typeof title === 'string' && title.trim().length > 0) {
        actions.push({ action: 'ACTION_SET_PLAYLIST_NAME', playlistName: title.trim() });
      }
      if (typeof description === 'string') {
        actions.push({ action: 'ACTION_SET_PLAYLIST_DESCRIPTION', playlistDescription: description });
      }
      if (typeof privacyStatus === 'string' && privacyStatus.length > 0) {
        actions.push({ action: 'ACTION_SET_PLAYLIST_PRIVACY', playlistPrivacy: privacyStatus });
      }
      if (!playlistId || actions.length === 0) return JSON.stringify({ ok: false });
      const data = await innertube('browse/edit_playlist', { playlistId, actions });
      return JSON.stringify({ ok: data?.status === 'STATUS_SUCCEEDED' || !data?.error });
    },

    async addTrackToPlaylist(rawPlaylistId, videoId) {
      const playlistId = (rawPlaylistId || '').replace(/^VL/, '');
      if (!playlistId || !videoId) return JSON.stringify({ ok: false });
      const data = await innertube('browse/edit_playlist', {
        playlistId,
        actions: [
          {
            action: 'ACTION_ADD_VIDEO',
            addedVideoId: videoId,
            dedupeOption: 'DEDUPE_OPTION_CHECK'
          }
        ]
      });
      return JSON.stringify({ ok: data?.status === 'STATUS_SUCCEEDED' || !data?.error });
    },

    async removeTrackFromPlaylist(rawPlaylistId, videoId, setVideoId) {
      const playlistId = (rawPlaylistId || '').replace(/^VL/, '');
      if (!playlistId || !videoId || !setVideoId) return JSON.stringify({ ok: false });
      const data = await innertube('browse/edit_playlist', {
        playlistId,
        actions: [
          {
            action: 'ACTION_REMOVE_VIDEO',
            setVideoId,
            removedVideoId: videoId
          }
        ]
      });
      return JSON.stringify({ ok: data?.status === 'STATUS_SUCCEEDED' || !data?.error });
    },

    async deletePlaylist(rawPlaylistId) {
      const playlistId = (rawPlaylistId || '').replace(/^VL/, '');
      if (!playlistId) return JSON.stringify({ ok: false });
      await innertube('playlist/delete', { playlistId });
      return JSON.stringify({ ok: true });
    },

    async likeTrack(videoId) {
      if (!videoId) return JSON.stringify({ ok: false });
      await innertube('like/like', { target: { videoId } });
      return JSON.stringify({ ok: true });
    },

    async fetchQueueAndLyrics(videoId) {
      if (!videoId) return JSON.stringify({ queue: [], lyrics: null });

      let activePlaylistId = null;
      try {
        const mp = getMoviePlayer();
        if (mp && typeof mp.getPlaylistId === 'function') {
          activePlaylistId = mp.getPlaylistId() || null;
        }
      } catch (_) {}
      if (!activePlaylistId) {
        activePlaylistId = new URLSearchParams(window.location.search).get('list') || null;
      }

      const nextBody = { videoId, isAudioOnly: true, enablePersistentPlaylistPanel: true };
      if (activePlaylistId) nextBody.playlistId = activePlaylistId;

      const data = await innertube('next', nextBody);
      const tabs =
        data?.contents?.singleColumnMusicWatchNextResultsRenderer?.tabbedRenderer
          ?.watchNextTabbedResultsRenderer?.tabs || [];

      const queue = [];
      let lyricsBrowseId = null;

      function extractQueueItem(c) {
        const pvr =
          c.playlistPanelVideoRenderer ||
          c.playlistPanelVideoWrapperRenderer?.primaryRenderer?.playlistPanelVideoRenderer ||
          c.playlistPanelVideoWrapperRenderer?.counterpart?.[0]?.counterpartRenderer
            ?.playlistPanelVideoRenderer;
        if (!pvr) return null;
        const title = runsText(pvr.title);
        const subtitle = runsText(pvr.shortBylineText || pvr.longBylineText);
        const artworkURL = bestThumbnail(pvr.thumbnail?.thumbnails);
        const dur = runsText(pvr.lengthText);
        const vid = pvr.videoId || pvr.navigationEndpoint?.watchEndpoint?.videoId;
        const plId = pvr.navigationEndpoint?.watchEndpoint?.playlistId || activePlaylistId || null;
        if (!vid || !title) return null;

        let artistBrowseId = null;
        let albumBrowseId = null;
        const bylineRuns = pvr.longBylineText?.runs || pvr.shortBylineText?.runs || [];
        for (const run of bylineRuns) {
          const bid = run?.navigationEndpoint?.browseEndpoint?.browseId;
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

        return {
          id: vid,
          title,
          subtitle,
          artworkURL,
          kind: 'song',
          videoId: vid,
          browseId: null,
          playlistId: plId,
          durationText: dur || null,
          albumTitle: null,
          artistBrowseId,
          albumBrowseId,
          isExplicit: false
        };
      }

      for (const tab of tabs) {
        const tr = tab.tabRenderer;
        if (!tr) continue;

        const queueContents = tr.content?.musicQueueRenderer?.content?.playlistPanelRenderer?.contents;
        if (Array.isArray(queueContents)) {
          for (const c of queueContents) {
            const item = extractQueueItem(c);
            if (item) queue.push(item);
          }
        }

        const epBrowseId = tr.endpoint?.browseEndpoint?.browseId;
        const tabTitle = (tr.title || '').toLowerCase();
        if (
          epBrowseId &&
          (epBrowseId.startsWith(BROWSE_PREFIX.LYRICS) ||
            tabTitle.includes('lyric') ||
            tabTitle.includes('歌词') ||
            tabTitle.includes('歌詞'))
        ) {
          lyricsBrowseId = epBrowseId;
        }
      }

      // DOM fallback for queue if API returned empty
      if (queue.length === 0) {
        const domItems = document.querySelectorAll(SELECTORS.QUEUE_ITEM);
        domItems.forEach((el, i) => {
          const t = el.querySelector('.song-title')?.textContent?.trim() || '';
          const a = el.querySelector('.byline')?.textContent?.trim() || '';
          const d = el.querySelector('.duration')?.textContent?.trim() || null;
          const img = el.querySelector('img')?.src || '';
          const vid = el.data?.videoId || el.__data?.data?.videoId || null;
          if (t && vid) {
            queue.push({
              id: `${vid}-${i}`,
              title: t,
              subtitle: a,
              artworkURL: upgradeArtwork(img),
              kind: 'song',
              videoId: vid,
              browseId: null,
              playlistId: activePlaylistId,
              durationText: d,
              albumTitle: null,
              isExplicit: false
            });
          }
        });
      }

      let lyrics = null;
      if (lyricsBrowseId) {
        try {
          const lyrData = await innertube('browse', { browseId: lyricsBrowseId });
          lyrics = findLyricsInObject(lyrData, 0);
        } catch (_) {}
      }

      return JSON.stringify({ queue, lyrics });
    }
  };

  startStateTicker();
  window.__lollipopInitialized = true;
  delete window.__lollipopInternal;
})();
