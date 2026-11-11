import email.utils
import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from liris.core import assess, normalized, signature, timing_conflict


def valid_candidate(c):
    return (isinstance(c, dict) and isinstance(c.get('trackName'), str)
            and isinstance(c.get('artistName'), str)
            and all(c.get(k) is None or isinstance(c[k], str) for k in ('syncedLyrics', 'plainLyrics', 'albumName')))


class LyricsClient:
    def __init__(self, store, base='https://lrclib.net/api', opener=urllib.request.urlopen):
        self.store, self.base, self.opener = store, base, opener
        self.cooldown = 0
        self.lock = threading.Lock()

    def request(self, path, params):
        with self.lock:
            if time.time() < self.cooldown:
                raise ValueError('LRCLIB sedang membatasi permintaan. Coba lagi nanti.')
        url = self.base + path + '?' + urllib.parse.urlencode(params)
        request = urllib.request.Request(url, headers={'User-Agent': 'LirisWindows/0.1 (+https://github.com/Fikriazrbni/Liris)',
                                                       'Accept': 'application/json'})
        try:
            with self.opener(request, timeout=12) as response:
                if 'application/json' not in response.headers.get('Content-Type', '').lower():
                    raise ValueError('LRCLIB tidak mengembalikan JSON')
                body = response.read(4_000_001)
                if len(body) > 4_000_000:
                    raise ValueError('Respons LRCLIB terlalu besar')
                return json.loads(body)
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            if error.code in (429, 503):
                value = error.headers.get('Retry-After', '60')
                try:
                    seconds = float(value)
                except ValueError:
                    try:
                        seconds = email.utils.parsedate_to_datetime(value).timestamp() - time.time()
                    except (ValueError, TypeError):
                        seconds = 60
                with self.lock:
                    self.cooldown = time.time() + max(60, min(seconds, 86400))
            raise ValueError('LRCLIB HTTP ' + str(error.code)) from error

    def search(self, query):
        result = self.request('/search', {'q': query})
        if not isinstance(result, list):
            raise ValueError('Format pencarian LRCLIB tidak valid')
        return [x for x in result[:32] if valid_candidate(x)]

    def resolve(self, track, force=False):
        key = signature(track)
        local = self.store.track(key)
        candidates = local.get('candidates', [])
        if not isinstance(candidates, list):
            candidates = []
        candidates = [c for c in candidates if valid_candidate(c)]
        status = 'Cache; kecocokan vokal belum terbukti'
        if force or not candidates or time.time() - local.get('comparedAt', 0) > 7 * 86400:
            errors = []
            exact = None
            found = []
            search_succeeded = False
            params = {'track_name': track['title'], 'artist_name': track['artist']}
            if track.get('duration', 0) > 0:
                params['duration'] = track['duration']
            try:
                exact = self.request('/get', params)
            except (OSError, ValueError) as error:
                errors.append('exact: ' + str(error))
            # A failed exact request must not discard the independent search
            # fallback. request() still enforces Retry-After before any HTTP call.
            try:
                found = self.search(track['title'] + ' ' + track['artist'])
                search_succeeded = True
            except (OSError, ValueError) as error:
                errors.append('search: ' + str(error))
            if valid_candidate(exact):
                found.insert(0, exact)
            if found or search_succeeded:
                unique = {}
                for c in (candidates if not search_succeeded else []) + found:
                    unique[str(c.get('id', c.get('syncedLyrics', '')))] = c
                candidates = list(unique.values())[:32]
                local = self.store.update_track(key, {'candidates': candidates,
                                                     'comparedAt': time.time() if search_succeeded else 0})
                status = ('Metadata/durasi diperiksa' if track.get('duration', 0) > 0
                          else 'Metadata diperiksa; durasi pemutar belum diketahui') + '; kecocokan vokal belum terbukti'
                if errors:
                    status += ' — pemeriksaan sebagian: ' + '; '.join(errors)
            else:
                status = 'Offline/error: ' + '; '.join(errors) + '; memakai cache bila cocok'
        safe = [c for c in candidates if not assess(c, track)]
        safe.sort(key=lambda c: (normalized(c.get('albumName') or '') != normalized(track.get('album', '')),
                                 abs(c.get('duration', 0) - track.get('duration', 0))))
        chosen = next((c for c in safe if c.get('id') == local.get('choice')), safe[0] if safe else None)
        if chosen is None and track.get('origin') == 'audio':
            unverified = [c for c in candidates if assess(c, track) == ['durasi belum dapat diverifikasi']]
            if unverified:
                chosen = unverified[0]
                status += ' — AUDIO: durasi/versi belum terverifikasi, posisi perkiraan'
        if timing_conflict(safe):
            status += ' — KONFLIK TIMING antar versi'
        if not chosen:
            status += ' — tidak ada versi aman; cari atau impor secara manual'
        return chosen, candidates, status
