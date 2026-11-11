import io
import json
import tempfile
import time
import unittest
import urllib.error
from unittest.mock import patch

from liris.core import signature
from liris.lyrics import LyricsClient
from liris.storage import Store
from test_core import candidate, packet


class Response(io.BytesIO):
    headers = {'Content-Type': 'application/json'}


class LyricsTests(unittest.TestCase):
    def test_url_encoding_json_contract_and_manual_search(self):
        urls = []
        def opener(request, timeout):
            urls.append(request.full_url)
            return Response(json.dumps([candidate()]).encode())
        with tempfile.TemporaryDirectory() as root:
            client = LyricsClient(Store(root), opener=opener)
            self.assertEqual(len(client.search('A&B 日本語')), 1)
        self.assertIn('A%26B+', urls[0])
        self.assertIn('%E6%97%A5', urls[0])

    def test_rate_limit_cooldown_avoids_repeated_network_calls(self):
        count = 0
        def opener(request, timeout):
            nonlocal count
            count += 1
            raise urllib.error.HTTPError(request.full_url, 429, 'Rate limited', {'Retry-After': '120'}, None)
        with tempfile.TemporaryDirectory() as root:
            client = LyricsClient(Store(root), opener=opener)
            for _ in range(2):
                with self.assertRaises(ValueError):
                    client.search('Song')
            self.assertEqual(count, 1)

    def test_html_rejected(self):
        def opener(request, timeout):
            response = Response(b'<html>error</html>')
            response.headers = {'Content-Type': 'text/html'}
            return response
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError, 'JSON'):
                LyricsClient(Store(root), opener=opener).search('Song')

    def test_offline_cache_revalidated_and_bad_duration_never_autoselected(self):
        def offline(*a, **kw):
            raise OSError('offline')
        with tempfile.TemporaryDirectory() as root:
            store = Store(root)
            store.put_track(signature(packet()), {'candidates': [candidate(duration=500), candidate(id=2)], 'choice': 1})
            chosen, versions, status = LyricsClient(store, opener=offline).resolve(packet())
            self.assertEqual(chosen['id'], 2)
            self.assertIn('Offline', status)

    def test_cached_versions_and_choice_preserved_until_force_refresh(self):
        with tempfile.TemporaryDirectory() as root:
            store = Store(root)
            store.put_track(signature(packet()), {'comparedAt': time.time(), 'candidates': [candidate(), candidate(id=2)], 'choice': 2, 'offset': 1.2})
            client = LyricsClient(store)
            with patch.object(client, 'request', side_effect=AssertionError('network not expected')):
                self.assertEqual(client.resolve(packet())[0]['id'], 2)
            with patch.object(client, 'request', side_effect=[candidate(id=3), [candidate(id=3)]]):
                self.assertEqual(client.resolve(packet(), force=True)[0]['id'], 3)
            self.assertEqual(store.track(signature(packet()))['offset'], 1.2)

    def test_audio_unknown_duration_is_explicitly_unverified(self):
        with tempfile.TemporaryDirectory() as root:
            client = LyricsClient(Store(root))
            with patch.object(client, 'request', side_effect=[candidate(), [candidate()]]):
                chosen, _, status = client.resolve(packet(origin='audio', duration=0))
            self.assertIsNotNone(chosen)
            self.assertIn('durasi/versi belum terverifikasi', status)

    def test_network_completion_preserves_offset_changed_during_fetch(self):
        with tempfile.TemporaryDirectory() as root:
            store = Store(root)
            key = signature(packet())
            client = LyricsClient(store)
            def reply(path, params):
                store.update_track(key, {'offset': 2.4})
                return candidate() if path == '/get' else [candidate()]
            with patch.object(client, 'request', side_effect=reply):
                client.resolve(packet())
            self.assertEqual(store.track(key)['offset'], 2.4)

    def test_malformed_candidate_cache_is_not_used(self):
        with tempfile.TemporaryDirectory() as root:
            store = Store(root)
            store.put_track(signature(packet()), {'candidates': [candidate(syncedLyrics={}), candidate(id=2)], 'comparedAt': time.time()})
            self.assertEqual(LyricsClient(store).resolve(packet())[0]['id'], 2)

    def test_exact_timeout_still_uses_search_fallback(self):
        with tempfile.TemporaryDirectory() as root:
            client = LyricsClient(Store(root))
            with patch.object(client, 'request', side_effect=[OSError('TLS handshake timed out'), [candidate()]]) as request:
                chosen, _, status = client.resolve(packet())
            self.assertEqual(chosen['id'], 1)
            self.assertEqual([c.args[0] for c in request.call_args_list], ['/get', '/search'])
            self.assertIn('pemeriksaan sebagian', status)

    def test_search_timeout_keeps_exact_and_does_not_mark_comparison_complete(self):
        with tempfile.TemporaryDirectory() as root:
            store = Store(root)
            client = LyricsClient(store)
            with patch.object(client, 'request', side_effect=[candidate(), OSError('timeout')]):
                chosen, _, status = client.resolve(packet())
            self.assertEqual(chosen['id'], 1)
            self.assertEqual(store.track(signature(packet()))['comparedAt'], 0)
            self.assertIn('pemeriksaan sebagian', status)

    def test_exact_rate_limit_prevents_search_http_request(self):
        calls = []
        def limited(request, timeout):
            calls.append(request.full_url)
            raise urllib.error.HTTPError(request.full_url, 429, 'Rate limited', {'Retry-After': '120'}, None)
        with tempfile.TemporaryDirectory() as root:
            chosen, _, _ = LyricsClient(Store(root), opener=limited).resolve(packet())
        self.assertIsNone(chosen)
        self.assertEqual(len(calls), 1)


if __name__ == '__main__':
    unittest.main()
