(function () {
  'use strict';
  if (window.__lollipopInitialized) return;

  const Internal = window.__lollipopInternal;
  const { CONSTANTS, SELECTORS, injectAudioOnlyCSS, post, getYtCfg, upgradeArtwork } = Internal;

  function getMoviePlayer() {
    return document.getElementById(SELECTORS.MOVIE_PLAYER);
  }

  function getVideoEl() {
    return document.querySelector(SELECTORS.MAIN_VIDEO) || document.querySelector(SELECTORS.ANY_VIDEO);
  }

  function readPlayerState() {
    const video = getVideoEl();
    const mp = getMoviePlayer();
    const bar = document.querySelector(SELECTORS.PLAYER_BAR);
    const ms = navigator.mediaSession && navigator.mediaSession.metadata;

    let videoId = '';
    try {
      if (mp && typeof mp.getVideoData === 'function') {
        videoId = mp.getVideoData()?.video_id || '';
      }
    } catch (_) {}
    if (!videoId) {
      const u = new URLSearchParams(window.location.search);
      videoId = u.get('v') || '';
    }

    let title = (ms && ms.title) || '';
    let artist = (ms && ms.artist) || '';
    let album = (ms && ms.album) || '';
    let artworkURL = '';

    if (ms && Array.isArray(ms.artwork) && ms.artwork.length > 0) {
      artworkURL = upgradeArtwork(ms.artwork[ms.artwork.length - 1].src || '');
    }

    let artistBrowseId = '';
    let albumBrowseId = '';
    if (bar) {
      if (!title) {
        const titleEl = bar.querySelector(SELECTORS.PLAYER_BAR_TITLE);
        if (titleEl) title = titleEl.textContent.trim();
      }
      if (!artist) {
        const subEl = bar.querySelector(SELECTORS.PLAYER_BAR_BYLINE);
        if (subEl) artist = subEl.textContent.trim();
      }
      if (!artworkURL) {
        const img = bar.querySelector(SELECTORS.PLAYER_BAR_IMAGE);
        if (img && img.src) artworkURL = upgradeArtwork(img.src);
      }
      const links = bar.querySelectorAll(SELECTORS.PLAYER_BAR_BYLINE_LINKS);
      links.forEach(a => {
        const href = a.getAttribute('href') || '';
        const chMatch = href.match(/\/channel\/(UC[A-Za-z0-9_-]+)/);
        if (chMatch && !artistBrowseId) artistBrowseId = chMatch[1];
        const brMatch = href.match(/\/browse\/((?:MPREb_|OLAK)[A-Za-z0-9_-]+)/);
        if (brMatch && !albumBrowseId) albumBrowseId = brMatch[1];
      });
    }

    let isPlaying = false;
    let currentTime = 0;
    let duration = 0;
    let volume = 100;
    let isMuted = false;

    if (video) {
      isPlaying = !video.paused && !video.ended && video.readyState > 0;
      currentTime = Number.isFinite(video.currentTime) ? video.currentTime : 0;
      duration = Number.isFinite(video.duration) ? video.duration : 0;
      volume = Math.round((video.volume ?? 1) * 100);
      isMuted = !!video.muted;
    }

    if (mp) {
      try {
        if (typeof mp.getVolume === 'function') volume = mp.getVolume();
        if (typeof mp.isMuted === 'function') isMuted = mp.isMuted();
        if (typeof mp.getDuration === 'function' && !duration) {
          const d = mp.getDuration();
          if (Number.isFinite(d) && d > 0) duration = d;
        }
      } catch (_) {}
    }

    let likeStatus = 'indifferent';
    const likeRenderer = bar?.querySelector(SELECTORS.LIKE_RENDERER);
    if (likeRenderer) {
      const ls = likeRenderer.getAttribute('like-status');
      if (ls === 'LIKE') likeStatus = 'like';
      else if (ls === 'DISLIKE') likeStatus = 'dislike';
    }

    let repeatMode = 'off';
    const repeatBtn = bar?.querySelector(SELECTORS.REPEAT_BUTTON);
    if (repeatBtn) {
      const aria = (repeatBtn.getAttribute('aria-label') || repeatBtn.getAttribute('title') || '').toLowerCase();
      if (aria.includes('one')) repeatMode = 'one';
      else if (aria.includes('all')) repeatMode = 'all';
    }

    let isShuffled = false;
    const shuffleBtn = bar?.querySelector(SELECTORS.SHUFFLE_BUTTON);
    if (shuffleBtn) {
      isShuffled = shuffleBtn.getAttribute('aria-pressed') === 'true';
    }

    const cfg = getYtCfg();
    const isSignedIn = !!(cfg && cfg.loggedIn);

    return {
      videoId,
      title,
      artist,
      album,
      artworkURL,
      isPlaying,
      isBuffering,
      currentTime,
      duration,
      volume,
      isMuted,
      repeatMode,
      isShuffled,
      likeStatus,
      isSignedIn,
      accountName: '',
      artistBrowseId,
      albumBrowseId,
      isReady: !!(cfg && cfg.apiKey)
    };
  }

  let lastReadyNotified = false;
  let listenersStarted = false;
  let isBuffering = false;
  let attachedVideo = null;
  let barObserver = null;
  let bootstrapObserver = null;
  let emitTimer = null;
  let lastPostedSignature = '';

  const VIDEO_EVENTS = [
    'play',
    'pause',
    'playing',
    'waiting',
    'stalled',
    'canplay',
    'seeking',
    'seeked',
    'durationchange',
    'volumechange',
    'ratechange',
    'loadedmetadata',
    'ended'
  ];

  function emitState(force) {
    injectAudioOnlyCSS();
    const state = readPlayerState();
    const sig = JSON.stringify([
      state.videoId,
      state.title,
      state.artist,
      state.album,
      state.artworkURL,
      state.isPlaying,
      state.isBuffering,
      Math.round(state.currentTime * 4),
      Math.round(state.duration),
      state.volume,
      state.isMuted,
      state.repeatMode,
      state.isShuffled,
      state.likeStatus,
      state.isSignedIn,
      state.artistBrowseId,
      state.albumBrowseId,
      state.isReady
    ]);
    if (force || sig !== lastPostedSignature) {
      lastPostedSignature = sig;
      post('playerState', state);
    }
    if (state.isReady && !lastReadyNotified) {
      lastReadyNotified = true;
      post('engineReady', { isSignedIn: state.isSignedIn });
    }
  }

  function scheduleEmit(delayMs) {
    if (emitTimer) clearTimeout(emitTimer);
    emitTimer = setTimeout(() => {
      emitTimer = null;
      emitState(false);
    }, delayMs);
  }

  function handleVideoEvent(ev) {
    if (ev.type === 'waiting' || ev.type === 'stalled') {
      isBuffering = true;
    } else if (ev.type === 'playing' || ev.type === 'canplay' || ev.type === 'seeked' || ev.type === 'pause' || ev.type === 'ended') {
      isBuffering = false;
    }
    emitState(true);
  }

  function attachMediaListeners() {
    const video = getVideoEl();
    if (video && video !== attachedVideo) {
      if (attachedVideo) {
        VIDEO_EVENTS.forEach(t => attachedVideo.removeEventListener(t, handleVideoEvent));
      }
      attachedVideo = video;
      VIDEO_EVENTS.forEach(t => video.addEventListener(t, handleVideoEvent));
      emitState(true);
    }

    const bar = document.querySelector(SELECTORS.PLAYER_BAR);
    if (bar && !barObserver) {
      barObserver = new MutationObserver(() => {
        attachMediaListeners();
        scheduleEmit(80);
      });
      barObserver.observe(bar, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['aria-pressed', 'aria-label', 'title', 'src', 'href']
      });
      emitState(true);
    }

    if (attachedVideo && barObserver && bootstrapObserver) {
      bootstrapObserver.disconnect();
      bootstrapObserver = null;
    }
  }

  function startStateTicker() {
    if (listenersStarted) return;
    listenersStarted = true;

    attachMediaListeners();
    emitState(true);

    if (!attachedVideo || !barObserver) {
      bootstrapObserver = new MutationObserver(() => {
        attachMediaListeners();
      });
      const root = document.body || document.documentElement;
      if (root) {
        bootstrapObserver.observe(root, { childList: true, subtree: true });
      }
    }

    window.addEventListener('load', () => {
      injectAudioOnlyCSS();
      attachMediaListeners();
      setTimeout(() => {
        attachMediaListeners();
        emitState(true);
      }, CONSTANTS.LOAD_TICK_DELAY_MS);
    });
  }

  const playerControls = {
    getState() {
      return readPlayerState();
    },

    togglePlay() {
      const btn = document.querySelector(SELECTORS.PLAY_PAUSE_BUTTON);
      if (btn) {
        btn.click();
        return true;
      }
      const video = getVideoEl();
      if (video) {
        if (video.paused) video.play().catch(() => {});
        else video.pause();
        return true;
      }
      return false;
    },

    play() {
      const video = getVideoEl();
      if (video && video.paused) {
        const btn = document.querySelector(SELECTORS.PLAY_PAUSE_BUTTON);
        if (btn) btn.click();
        else video.play().catch(() => {});
      }
    },

    pause() {
      const video = getVideoEl();
      if (video && !video.paused) {
        const btn = document.querySelector(SELECTORS.PLAY_PAUSE_BUTTON);
        if (btn) btn.click();
        else video.pause();
      }
    },

    next() {
      const btn = document.querySelector(SELECTORS.NEXT_BUTTON);
      if (btn) {
        btn.click();
        return true;
      }
      return false;
    },

    previous() {
      const btn = document.querySelector(SELECTORS.PREVIOUS_BUTTON);
      if (btn) {
        btn.click();
        return true;
      }
      return false;
    },

    seek(seconds) {
      const mp = getMoviePlayer();
      if (mp && typeof mp.seekTo === 'function') {
        mp.seekTo(seconds, true);
        return true;
      }
      const video = getVideoEl();
      if (video) {
        video.currentTime = seconds;
        return true;
      }
      return false;
    },

    setVolume(vol) {
      const clamped = Math.max(0, Math.min(100, Math.round(vol)));
      const mp = getMoviePlayer();
      if (mp && typeof mp.setVolume === 'function') {
        mp.setVolume(clamped);
        if (clamped > 0 && typeof mp.isMuted === 'function' && mp.isMuted() && typeof mp.unMute === 'function') {
          mp.unMute();
        }
      }
      const video = getVideoEl();
      if (video) {
        video.volume = clamped / 100;
        if (clamped > 0) video.muted = false;
      }
      const slider = document.querySelector(SELECTORS.VOLUME_SLIDER);
      if (slider) {
        slider.value = clamped;
        slider.dispatchEvent(new Event('change', { bubbles: true }));
      }
      return true;
    },

    toggleMute() {
      const mp = getMoviePlayer();
      if (mp && typeof mp.isMuted === 'function') {
        if (mp.isMuted()) mp.unMute();
        else mp.mute();
        return true;
      }
      const video = getVideoEl();
      if (video) {
        video.muted = !video.muted;
        return true;
      }
      return false;
    },

    toggleLike() {
      const btn = document.querySelector(SELECTORS.LIKE_BUTTON);
      if (btn) {
        btn.click();
        return true;
      }
      return false;
    },

    toggleShuffle() {
      const btn = document.querySelector(SELECTORS.PLAYER_BAR_SHUFFLE);
      if (btn) {
        btn.click();
        return true;
      }
      return false;
    },

    cycleRepeat() {
      const btn = document.querySelector(SELECTORS.PLAYER_BAR_REPEAT);
      if (btn) {
        btn.click();
        return true;
      }
      return false;
    },

    playVideo(videoId, playlistId, params) {
      const app = document.querySelector(SELECTORS.YTMUSIC_APP);
      const effectivePlaylistId = playlistId || null;
      Internal.lastRequestedPlayback = {
        videoId: videoId || null,
        playlistId: effectivePlaylistId,
        params: params || null,
        at: Date.now()
      };

      const endpoint = videoId
        ? {
            watchEndpoint: {
              videoId,
              ...(effectivePlaylistId ? { playlistId: effectivePlaylistId } : {}),
              ...(params ? { params } : {})
            }
          }
        : {
            watchPlaylistEndpoint: {
              ...(effectivePlaylistId ? { playlistId: effectivePlaylistId } : {}),
              ...(params ? { params } : {})
            }
          };

      if (app && typeof app.fire === 'function') {
        try {
          app.fire('yt-navigate', { endpoint });
          setTimeout(() => {
            const v = getVideoEl();
            if (v && v.paused) v.play().catch(() => {});
          }, CONSTANTS.NAV_PLAY_DELAY_MS);
          return true;
        } catch (_) {}
      }

      // Fallback URL navigation
      let url = `${CONSTANTS.ORIGIN}/watch?`;
      if (videoId) url += `v=${encodeURIComponent(videoId)}`;
      if (effectivePlaylistId) url += `${videoId ? '&' : ''}list=${encodeURIComponent(effectivePlaylistId)}`;
      if (params) url += `&params=${encodeURIComponent(params)}`;
      window.location.href = url;
      return true;
    }
  };

  Internal.getMoviePlayer = getMoviePlayer;
  Internal.readPlayerState = readPlayerState;
  Internal.startStateTicker = startStateTicker;
  Internal.playerControls = playerControls;
})();
