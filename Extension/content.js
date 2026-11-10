(() => {
  function snapshot() {
    const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
    const bar = document.querySelector('ytmusic-player-bar');
    if (!video) return null;
    const m = navigator.mediaSession?.metadata;
    let title = (bar?.querySelector('.title')?.textContent || m?.title || document.querySelector('h1.ytd-watch-metadata yt-formatted-string')?.textContent || '').trim();
    if (!title) return null;
    let artist = (bar?.querySelector('.byline a')?.textContent || m?.artist || document.querySelector('#owner #channel-name a')?.textContent || '').trim();
    if (!bar) {
      artist = artist.replace(/\s*-\s*Topic$/i, '').replace(/VEVO$/i, '').trim();
      const parts = title.split(/\s+[-–—]\s+/);
      const canonical = value => value.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
      if (parts.length >= 2 && canonical(parts[0]) === canonical(artist)) {
        artist = parts.shift().trim(); title = parts.join(' - ');
      }
      title = title.replace(/\s*[[(](?:official(?: music)? (?:video|audio)|lyrics?(?: video)?|hd)[\])]\s*$/ig, '').trim();
    }
    const progress = bar?.querySelector('#progress-bar');
    const value = progress?.getAttribute('aria-valuenow');
    const uiPosition = value != null ? Number(value) : NaN;
    const uiDuration = Number(progress?.getAttribute('aria-valuemax'));
    const position = Number.isFinite(uiPosition) && Math.abs(uiPosition - video.currentTime) > 1.25 ? uiPosition : video.currentTime;
    const state = navigator.mediaSession?.playbackState;
    return { trackID: new URL(location.href).searchParams.get('v') || title + '|' + artist, title, artist,
      quantized: Number.isFinite(uiPosition) && Math.abs(uiPosition - video.currentTime) > 1.25,
      album: m?.album || '', position: Number.isFinite(position) ? position : 0,
      duration: uiDuration > 0 ? uiDuration : Number.isFinite(video.duration) ? video.duration : 0,
      playing: state === 'playing' || (state !== 'paused' && !video.paused && !video.ended && video.readyState >= 2),
      advertisement: !!document.querySelector('.ad-showing, ytmusic-player-bar[is-advertisement]') };
  }
  let busy = false;
  setInterval(async () => {
    if (busy) return;
    const packet = snapshot(); if (!packet) return;
    busy = true;
    try { await chrome.runtime.sendMessage({ kind: 'liris-snapshot', packet }); } catch (_) {} finally { busy = false; }
  }, 500);
  chrome.runtime.onMessage.addListener(message => {
    if (message.kind !== 'liris-control' || message.trackID !== snapshot()?.trackID) return;
    const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
    if (!video) return;
    if (message.command === 'toggle') {
      const button = document.querySelector('ytmusic-player-bar #play-pause-button') || document.querySelector('.ytp-play-button');
      button?.click();
    }
    if (message.command === 'seek' && Number.isFinite(message.target) && message.target >= 0) {
      // Do not seek a retained media node that disagrees with the visible player.
      if (Math.abs(video.currentTime - snapshot().position) <= 1.25) video.currentTime = Math.min(message.target, video.duration);
    }
  });
})();
