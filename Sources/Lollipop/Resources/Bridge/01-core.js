(function () {
  'use strict';
  if (window.__lollipopInitialized) return;

  const Internal = (window.__lollipopInternal = window.__lollipopInternal || {});

  const CONSTANTS = {
    ORIGIN: 'https://music.youtube.com',
    CLIENT_NAME: '67',
    DEFAULT_CLIENT_VERSION: '1.20250101.01.00',
    POLL_INTERVAL_MS: 500,
    LOAD_TICK_DELAY_MS: 300,
    NAV_PLAY_DELAY_MS: 800,
    BROWSE_PREFIX: {
      ARTIST: 'UC',
      ALBUM: 'MPREb_',
      ALBUM_PLAYLIST: 'OLAK',
      PLAYLIST_VL: 'VL',
      RADIO: 'RD',
      LYRICS: 'MPLYt'
    },
    BROWSE_ID: {
      LIKED_PLAYLISTS: 'FEmusic_liked_playlists',
      LIBRARY_LANDING: 'FEmusic_library_landing',
      LIKED_MUSIC_VL: 'VLLM',
      LIKED_MUSIC_SHORT: 'LM',
      EPISODES_FOR_LATER_VL: 'VLSE',
      EPISODES_FOR_LATER_SHORT: 'SE'
    }
  };

  const SELECTORS = {
    AUDIO_ONLY_STYLE_ID: 'lollipop-audio-only-style',
    MOVIE_PLAYER: 'movie_player',
    MAIN_VIDEO: 'video.html5-main-video',
    ANY_VIDEO: 'video',
    PLAYER_BAR: 'ytmusic-player-bar',
    PLAYER_BAR_TITLE: '.title.ytmusic-player-bar',
    PLAYER_BAR_BYLINE: '.byline.ytmusic-player-bar',
    PLAYER_BAR_BYLINE_LINKS: '.byline.ytmusic-player-bar a',
    PLAYER_BAR_IMAGE: 'img.image.ytmusic-player-bar',
    LIKE_RENDERER: 'ytmusic-like-button-renderer',
    LIKE_BUTTON: 'ytmusic-player-bar ytmusic-like-button-renderer .like',
    REPEAT_BUTTON: '.repeat',
    SHUFFLE_BUTTON: '.shuffle',
    PLAYER_BAR_REPEAT: 'ytmusic-player-bar .repeat',
    PLAYER_BAR_SHUFFLE: 'ytmusic-player-bar .shuffle',
    PLAY_PAUSE_BUTTON: '#play-pause-button',
    NEXT_BUTTON: '.next-button',
    PREVIOUS_BUTTON: '.previous-button',
    VOLUME_SLIDER: '#volume-slider',
    YTMUSIC_APP: 'ytmusic-app',
    AVATAR_IMAGE: 'ytmusic-settings-button img, #avatar-btn img',
    QUEUE_ITEM: 'ytmusic-player-queue-item'
  };

  // MediaSession Normalization (Prevents 15s skip buttons in macOS Control Center)
  (function patchMediaSession() {
    if (!navigator.mediaSession || typeof navigator.mediaSession.setActionHandler !== 'function') return;
    const origSetHandler = navigator.mediaSession.setActionHandler.bind(navigator.mediaSession);
    navigator.mediaSession.setActionHandler = function (action, handler) {
      if (action === 'seekforward' || action === 'seekbackward') {
        try {
          return origSetHandler(action, null);
        } catch (_) {
          return;
        }
      }
      return origSetHandler(action, handler);
    };
    try {
      origSetHandler('seekforward', null);
      origSetHandler('seekbackward', null);
    } catch (_) {}
  })();

  function injectAudioOnlyCSS() {
    if (document.getElementById(SELECTORS.AUDIO_ONLY_STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = SELECTORS.AUDIO_ONLY_STYLE_ID;
    style.textContent = `
      /* Keep audio pipeline 100% active while suppressing video rendering overhead */
      video.html5-main-video {
        opacity: 0.001 !important;
        pointer-events: none !important;
      }
      .ytp-iv-video-content,
      .ytp-ce-element,
      ytmusic-av-toggle {
        pointer-events: none !important;
      }
    `;
    (document.head || document.documentElement).appendChild(style);
  }

  function post(type, payload) {
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lollipop) {
        window.webkit.messageHandlers.lollipop.postMessage({ type, payload });
      }
    } catch (_) {}
  }

  function getCookie(name) {
    const escaped = name.replace(/[.$?*|{}()[\]\\/+^]/g, '\\$&');
    const match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : null;
  }

  async function sha1Hex(str) {
    const buf = new TextEncoder().encode(str);
    const hash = await crypto.subtle.digest('SHA-1', buf);
    return Array.from(new Uint8Array(hash))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  }

  async function getAuthHeader() {
    const sapisid =
      getCookie('SAPISID') ||
      getCookie('__Secure-3PAPISID') ||
      getCookie('__Secure-1PAPISID');
    if (!sapisid) return null;
    const ts = Math.floor(Date.now() / 1000);
    const hash = await sha1Hex(`${ts} ${sapisid} ${CONSTANTS.ORIGIN}`);
    return `SAPISIDHASH ${ts}_${hash}`;
  }

  function getYtCfg() {
    const cfg = window.ytcfg;
    if (!cfg || typeof cfg.get !== 'function') return null;
    return {
      apiKey: cfg.get('INNERTUBE_API_KEY'),
      context: cfg.get('INNERTUBE_CONTEXT'),
      sessionIndex: cfg.get('SESSION_INDEX') || '0',
      loggedIn: !!cfg.get('LOGGED_IN')
    };
  }

  async function innertube(endpoint, body) {
    const cfg = getYtCfg();
    if (!cfg || !cfg.apiKey || !cfg.context) {
      throw new Error('YouTube Music session is still initializing.');
    }
    const headers = {
      'Content-Type': 'application/json',
      'X-Origin': CONSTANTS.ORIGIN,
      'X-Goog-AuthUser': String(cfg.sessionIndex || '0'),
      'X-YouTube-Client-Name': CONSTANTS.CLIENT_NAME,
      'X-YouTube-Client-Version':
        (cfg.context.client && cfg.context.client.clientVersion) || CONSTANTS.DEFAULT_CLIENT_VERSION
    };
    const auth = await getAuthHeader();
    if (auth) {
      headers['Authorization'] = auth;
    }
    const url = `${CONSTANTS.ORIGIN}/youtubei/v1/${endpoint}?key=${encodeURIComponent(cfg.apiKey)}&prettyPrint=false`;
    const res = await fetch(url, {
      method: 'POST',
      credentials: 'include',
      headers,
      body: JSON.stringify({
        context: cfg.context,
        ...body
      })
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} calling ${endpoint}`);
    }
    return await res.json();
  }

  function upgradeArtwork(url) {
    if (!url || typeof url !== 'string') return '';
    if (url.includes('googleusercontent.com')) {
      return url.replace(/=w\d+-h\d+[^&]*/, '=w544-h544-l90-rj');
    }
    if (url.includes('i.ytimg.com/vi/')) {
      return url.replace(/\/(default|mqdefault|hqdefault|sddefault)\.jpg/, '/hqdefault.jpg');
    }
    return url;
  }

  function bestThumbnail(thumbnails) {
    if (!Array.isArray(thumbnails) || thumbnails.length === 0) return '';
    const sorted = [...thumbnails].sort((a, b) => (b.width || 0) - (a.width || 0));
    return upgradeArtwork(sorted[0].url || '');
  }

  function runsText(obj) {
    if (!obj) return '';
    if (typeof obj === 'string') return obj;
    if (obj.simpleText) return obj.simpleText;
    if (Array.isArray(obj.runs)) return obj.runs.map(r => r.text || '').join('');
    return '';
  }

  Internal.CONSTANTS = CONSTANTS;
  Internal.SELECTORS = SELECTORS;
  Internal.injectAudioOnlyCSS = injectAudioOnlyCSS;
  Internal.post = post;
  Internal.getYtCfg = getYtCfg;
  Internal.innertube = innertube;
  Internal.upgradeArtwork = upgradeArtwork;
  Internal.bestThumbnail = bestThumbnail;
  Internal.runsText = runsText;
})();
