from __future__ import annotations

import bisect
import hashlib
import json
import math
import re
import time
import unicodedata
from dataclasses import dataclass


def normalized(value):
    return ''.join(c for c in unicodedata.normalize('NFKC', value).casefold() if c.isalnum())


def signature(track):
    fields = [normalized(track.get(k, '')) for k in ('title', 'artist', 'album')]
    fields.append(round(float(track.get('duration', 0))))
    return hashlib.sha256(json.dumps(fields).encode()).hexdigest()


def finite_number(value, low=0, high=864000):
    return type(value) in (int, float) and math.isfinite(value) and low <= value <= high


def valid_packet(p):
    return (isinstance(p, dict) and p.get('origin') in ('youtube', 'youtube-music')
            and isinstance(p.get('session'), str)
            and re.fullmatch(r'[a-zA-Z0-9_-]{1,100}', p['session']) is not None
            and all(isinstance(p.get(k), str) and len(p[k]) <= 1000
                    for k in ('trackID', 'title', 'artist', 'album'))
            and bool(p['title']) and all(finite_number(p.get(k)) for k in ('position', 'duration'))
            and all(type(p.get(k)) is bool for k in ('playing', 'advertisement'))
            and type(p.get('quantized', False)) is bool)


def fresh_packet(p, now=None):
    now = time.time() if now is None else now
    return valid_packet(p) and finite_number(p.get('receivedAt'), 0, 1e12) and 0 <= now - p['receivedAt'] < 3


def select_packet(packets, previous=None, now=None):
    fresh = [p for p in packets if fresh_packet(p, now)]
    playing = [p for p in fresh if p['playing']]
    pool = playing or fresh
    return next((p for p in pool if p['session'] == previous), max(pool, key=lambda p: p['receivedAt'], default=None))


@dataclass(frozen=True)
class Line:
    time: float
    text: str


def parse_lrc(text):
    """Preserve empty timed lines and multiple tags; LRC offset is milliseconds."""
    if not isinstance(text, str):
        return []
    offset = re.search(r'\[offset:\s*([+-]?\d+)\]', text, re.I)
    shift = int(offset[1]) / 1000 if offset else 0
    lines = []
    tag = re.compile(r'\[(\d{1,3}):([0-5]\d)(?:[.:](\d{1,3}))?\]')
    for raw in text.splitlines():
        matches = list(tag.finditer(raw))
        if not matches:
            continue
        content = tag.sub('', raw).strip()
        for m in matches:
            stamp = int(m[1]) * 60 + int(m[2]) + (int(m[3]) / 10 ** len(m[3]) if m[3] else 0)
            lines.append(Line(max(0, stamp + shift), content))
    return sorted(lines, key=lambda line: line.time)


def active_line(lines, position):
    return bisect.bisect_right([line.time for line in lines], position) - 1


def assess(candidate, track):
    reasons = []
    if normalized(candidate.get('trackName', '')) != normalized(track.get('title', '')):
        reasons.append('judul berbeda')
    artist, expected = normalized(candidate.get('artistName', '')), normalized(track.get('artist', ''))
    if not artist or not expected or artist != expected:
        reasons.append('artis berbeda/tidak diketahui')
    # Version qualifiers remain in normalized titles; never strip live/remix/cover.
    duration = candidate.get('duration')
    actual = track.get('duration', 0)
    if not finite_number(duration) or actual <= 0:
        reasons.append('durasi belum dapat diverifikasi')
    elif abs(duration - actual) > 5:
        reasons.append('durasi berbeda >5 detik')
    lines = parse_lrc(candidate.get('syncedLyrics') or '')
    if not lines:
        reasons.append('tanpa timestamp')
    elif actual > 0 and lines[-1].time > actual + 3:
        reasons.append('timestamp melewati akhir lagu')
    return reasons


def timing_conflict(candidates):
    import statistics
    maps = []
    for candidate in candidates:
        groups = {}
        for line in parse_lrc(candidate.get('syncedLyrics') or ''):
            key = normalized(line.text)
            if key:
                groups.setdefault(key, []).append(line.time)
        maps.append({k: v[0] for k, v in groups.items() if len(v) == 1})
    for i, left in enumerate(maps):
        for right in maps[i + 1:]:
            common = left.keys() & right.keys()
            if len(common) >= 4 and statistics.median(abs(left[k] - right[k]) for k in common) > 2:
                return True
    return False


class PlaybackClock:
    def __init__(self):
        self.position = 0.0
        self.anchor = 0.0
        self.playing = False
        self.quantized = False
        self.reading = None
        self.last_seen = 0.0
        self.duration = 0.0
        self.source = None

    def update(self, packet, now=None):
        now = time.monotonic() if now is None else now
        # Account for the bridge's wall-clock age at the moment of receipt only.
        reading = float(packet['position'])
        quantized = packet.get('quantized', False)
        source = (packet['session'], packet['trackID'])
        repeated = (source == self.source and quantized and self.quantized and self.playing
                    and packet['playing'] and self.reading == reading)
        if not repeated:
            age = max(0, min(3, time.time() - packet.get('receivedAt', time.time())))
            self.position = reading + (min(age, 1) if quantized else age) * packet['playing']
            self.anchor = now
        self.source = source
        self.reading = reading
        self.quantized = quantized
        self.playing = packet['playing']
        self.duration = packet['duration']
        self.last_seen = now

    def value(self, now=None):
        now = time.monotonic() if now is None else now
        elapsed = max(0, min(now, self.last_seen + 3) - self.anchor) if self.playing else 0
        value = self.position + (min(elapsed, 1) if self.quantized else elapsed)
        return min(value, self.duration) if self.duration > 0 else value
