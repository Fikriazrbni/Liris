const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const code = fs.readFileSync(path.join(__dirname, '../Sources/LirisApp/Resources/youtube-music.js'), 'utf8');

function probe({ title = 'Ruang Senja', artist = 'Liris Studio', video = {}, metadata, sessionState, ad = false, missing = false, progressMax, progressNow, timeInfo, url = 'https://music.youtube.com/watch?v=track-123&list=playlist' } = {}) {
  const nodes = {
    '.title': { textContent: title }, '.byline': { textContent: artist + ' • Album • 2026' },
    '.byline a': { textContent: artist }, img: { src: 'https://example.test/art.jpg' }
  };
  if (progressMax !== undefined || progressNow !== undefined) nodes['#progress-bar'] = {
    getAttribute: name => name === 'aria-valuemax' ? (progressMax === undefined ? null : String(progressMax))
      : name === 'aria-valuenow' ? (progressNow === undefined ? null : String(progressNow)) : null
  };
  if (timeInfo !== undefined) nodes['.time-info'] = { textContent: timeInfo };
  const player = { querySelector: selector => nodes[selector] };
  const media = { currentTime: 23.45, duration: 180, paused: false, ended: false, readyState: 4, ...video };
  const context = {
    document: { querySelector: selector => selector === 'ytmusic-player-bar' ? (missing ? null : player)
      : ['video', 'ytmusic-player video'].includes(selector) ? (missing ? null : media)
      : selector.startsWith('.ad-showing') && ad ? {} : null },
    navigator: { mediaSession: { metadata, playbackState: sessionState } },
    location: { href: url }, URL
  };
  return JSON.parse(vm.runInNewContext(code, context));
}

test('reads actual media position and identity rather than estimating duration', () => {
  const result = probe();
  assert.equal(result.id, 'track-123'); assert.equal(result.title, 'Ruang Senja');
  assert.equal(result.artist, 'Liris Studio'); assert.equal(result.position, 23.45);
  assert.equal(result.duration, 180); assert.equal(result.playing, true);
});
test('pause, buffering and ended states stop interpolation', () => {
  for (const video of [{ paused: true }, { readyState: 1 }, { ended: true }]) {
    assert.equal(probe({ video }).playing, false);
  }
});
test('missing media is not interpreted as a new song', () => assert.deepEqual(probe({ missing: true }), { available: false }));
test('non-finite media values never leak invalid JSON', () => {
  const result = probe({ video: { duration: Infinity, currentTime: NaN } });
  assert.equal(result.duration, 0); assert.equal(result.position, 0);
});
test('metadata fallback keeps Unicode and quotes intact', () => {
  const result = probe({ title: '', artist: '', metadata: { title: '夜 "A & B"', artist: 'アーティスト', album: 'Album' } });
  assert.equal(result.title, '夜 "A & B"'); assert.equal(result.artist, 'アーティスト'); assert.equal(result.album, 'Album');
});
test('ad state is explicit so stale lyrics can be suppressed', () => assert.equal(probe({ ad: true }).advertisement, true));

test('song progress duration wins over a growing MediaSource buffer', () => {
  for (const duration of [298.5512, 328.504941, 358.458683]) {
    const result = probe({ video: { currentTime: 232.676316, duration, paused: true }, progressMax: 239, timeInfo: '3:52 / 3:59' });
    assert.equal(result.duration, 239); assert.equal(result.position, 232.676316); assert.equal(result.playing, false);
  }
});
test('visible clock is a fallback when progress attributes are unavailable', () => {
  assert.equal(probe({ video: { duration: 358 }, timeInfo: '3:52 / 3:59' }).duration, 239);
  assert.equal(probe({ video: { duration: 358 }, progressMax: Infinity, timeInfo: '3:52 / 3:59' }).duration, 239);
  assert.equal(probe({ timeInfo: '01:03:52 / 01:04:59' }).duration, 3899);
});
test('home-page playback has a stable identity without a watch URL', () => {
  assert.equal(probe({ url: 'https://music.youtube.com/' }).id, 'Ruang Senja|Liris Studio');
});

test('21 Guns regression: visible 0:29 overrides a retained media clock at 2:52', () => {
  const result = probe({ video: { currentTime: 172.187185, duration: 321, paused: true },
    progressNow: 29, progressMax: 322, timeInfo: '0:29 / 5:22', sessionState: 'paused' });
  assert.equal(result.position, 29); assert.equal(result.duration, 322);
  assert.equal(result.positionSource, 'progress'); assert.equal(result.playing, false);
});
test('media precision is retained when it agrees with the visible clock', () => {
  const result = probe({ video: { currentTime: 29.725 }, progressNow: 29, progressMax: 322, sessionState: 'playing' });
  assert.equal(result.position, 29.725); assert.equal(result.positionSource, 'media'); assert.equal(result.playing, true);
});
test('active MediaSession overrides the pause state of an obsolete media element', () => {
  const result = probe({ video: { currentTime: 29, paused: true }, progressNow: 29, progressMax: 322, sessionState: 'playing' });
  assert.equal(result.playing, true); assert.equal(result.positionSource, 'progress');
  assert.equal(probe({ video: { paused: false }, sessionState: 'paused' }).playing, false);
});
test('visible current time zero is valid and does not fall back to an old clock', () => {
  const result = probe({ video: { currentTime: 172 }, progressNow: 0, progressMax: 322 });
  assert.equal(result.position, 0); assert.equal(result.positionSource, 'progress');
});
test('visible clock text supplies position when the progress value is absent', () => {
  const result = probe({ video: { currentTime: 172 }, timeInfo: '0:29 / 5:22' });
  assert.equal(result.position, 29); assert.equal(result.positionSource, 'progress');
});
