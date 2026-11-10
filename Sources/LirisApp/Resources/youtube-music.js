(() => {
  // Only this selected YouTube Music page is inspected; no browsing history is read.
  const player = document.querySelector('ytmusic-player-bar');
  const video = document.querySelector('ytmusic-player video') || document.querySelector('video');
  if (!player || !video) return JSON.stringify({ available: false });
  const metadata = navigator.mediaSession?.metadata;
  const text = selector => player.querySelector(selector)?.textContent?.trim() || '';
  const title = text('.title') || metadata?.title || '';
  const byline = text('.byline') || text('.subtitle');
  const artist = player.querySelector('.byline a')?.textContent?.trim()
    || metadata?.artist || byline.split(/\s*[•·]\s*/)[0] || '';
  const artwork = player.querySelector('img')?.src || metadata?.artwork?.at(-1)?.src || '';
  const videoID = new URL(location.href).searchParams.get('v') || title + '|' + artist;
  // YouTube's MediaSource duration can keep growing as buffers are appended,
  // even while paused. The song progress control contains the actual track length.
  const progress = player.querySelector('#progress-bar');
  const totalText = player.querySelector('.time-info')?.textContent?.split('/').at(-1)?.trim();
  const parseClock = value => {
    if (!/^\d+(?::[0-5]\d){1,2}$/.test(value || '')) return 0;
    return value.split(':').reduce((sum, part) => sum * 60 + Number(part), 0);
  };
  const progressDuration = Number(progress?.getAttribute('aria-valuemax'));
  const duration = Number.isFinite(progressDuration) && progressDuration > 0 ? progressDuration : parseClock(totalText)
    || (Number.isFinite(video.duration) ? video.duration : 0);
  const progressAttribute = progress?.getAttribute('aria-valuenow');
  const progressPosition = progressAttribute != null && progressAttribute !== '' ? Number(progressAttribute) : NaN;
  const clockText = player.querySelector('.time-info')?.textContent?.split('/')[0]?.trim();
  const hasClock = /^\d+(?::[0-5]\d){1,2}$/.test(clockText || '');
  const visiblePosition = Number.isFinite(progressPosition) && progressPosition >= 0
    ? progressPosition : hasClock ? parseClock(clockText) : null;
  const mediaPosition = Number.isFinite(video.currentTime) && video.currentTime >= 0 ? video.currentTime : null;
  const sessionState = navigator.mediaSession?.playbackState;
  // The retained media node may no longer follow the active song after seeks or
  // player changes. Only use its subsecond clock when it agrees with the UI.
  const stalePlaybackState = sessionState === 'playing' && (video.paused || video.ended || video.readyState < 2);
  const mediaAgrees = mediaPosition != null && !stalePlaybackState
    && (visiblePosition == null || Math.abs(mediaPosition - visiblePosition) <= 1.25);
  const position = mediaAgrees ? mediaPosition : visiblePosition ?? 0;
  const playing = sessionState === 'playing' ? true : sessionState === 'paused' ? false
    : !video.paused && !video.ended && video.readyState >= 2;
  const ad = !!document.querySelector('.ad-showing, .ytp-ad-player-overlay, ytmusic-player-bar[is-advertisement]');
  return JSON.stringify({
    available: !!title, id: videoID, title, artist,
    album: metadata?.album || '', artwork,
    position, positionSource: mediaAgrees ? 'media' : 'progress',
    mediaPosition, progressPosition: Number.isFinite(progressPosition) ? progressPosition : null,
    clockPosition: hasClock ? parseClock(clockText) : null,
    mediaPlaying: !video.paused && !video.ended && video.readyState >= 2,
    playbackRate: Number.isFinite(video.playbackRate) && video.playbackRate > 0 ? video.playbackRate : 1,
    duration,
    playing,
    advertisement: ad
  });
})()
