import copy
import io
import json
import math
import struct
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from liris.audio import AudioEngine, pcm_wav
from liris.bridge import extension_id, read_exact, serve
from liris.core import (PlaybackClock, active_line, assess, fresh_packet, parse_lrc,
                        select_packet, signature, timing_conflict, valid_packet)
from liris.storage import Store, atomic_json


def packet(**kwargs):
    p = dict(session='tab_1', origin='youtube-music', trackID='abc', title='Song', artist='Artist',
             album='Album', position=10., duration=180., playing=True, advertisement=False,
             quantized=False, receivedAt=time.time())
    return dict(p, **kwargs)


def candidate(**kwargs):
    c = dict(id=1, trackName='Song', artistName='Artist', albumName='Album', duration=180,
             syncedLyrics='[00:01]One\n[00:02]Two\n[00:03]Three\n[00:04]Four')
    return dict(c, **kwargs)


class CoreTests(unittest.TestCase):
    def test_lrc_multiple_tags_fraction_offset_blank_and_plain(self):
        lines = parse_lrc('[offset:-200]\n[00:01.5][01:02.050]Hello\n[00:03]\n[ar:Artist]')
        self.assertEqual([(x.time, x.text) for x in lines], [(1.3, 'Hello'), (2.8, ''), (61.849999999999994, 'Hello')])
        self.assertEqual(parse_lrc('plain text'), [])
        self.assertEqual(active_line(lines, 0), -1)
        self.assertEqual(active_line(lines, 3), 1)
        self.assertEqual(active_line(lines, 1.5), 0)

    def test_clock_pause_seek_track_change_expiry(self):
        clock = PlaybackClock()
        clock.update(packet(receivedAt=time.time()), now=100)
        self.assertAlmostEqual(clock.value(101), 11, delta=0.01)
        clock.update(packet(position=30, playing=False), now=101)
        self.assertEqual(clock.value(200), 30)
        clock.update(packet(position=4), now=200)
        self.assertAlmostEqual(clock.value(201), 5, delta=0.01)
        self.assertLess(clock.value(300), 7.01)
        clock.update(packet(trackID='new', position=0), now=301)
        self.assertLess(clock.value(301), 0.01)

    def test_quantized_repeat_does_not_reset_or_run_away(self):
        clock = PlaybackClock()
        clock.update(packet(position=10, quantized=True), now=100)
        clock.update(packet(position=10, quantized=True), now=100.5)
        self.assertAlmostEqual(clock.value(100.7), 10.7, delta=0.01)
        self.assertLessEqual(clock.value(200), 11.01)

    def test_packets_reject_paths_nan_bool_wrong_origin_and_expiry(self):
        self.assertTrue(valid_packet(packet()))
        for p in [packet(session='../bad'), packet(position=math.nan), packet(duration=True),
                  packet(playing='yes'), packet(origin='evil'), packet(title='')]:
            self.assertFalse(valid_packet(p))
        self.assertFalse(fresh_packet(packet(receivedAt=100), now=104))
        self.assertFalse(fresh_packet(packet(receivedAt=110), now=104))
        self.assertIsNone(select_packet([packet(receivedAt=100)], now=104))

    def test_playing_priority_and_stable_session(self):
        paused = packet(session='paused', playing=False)
        first = packet(session='first')
        second = packet(session='second')
        self.assertEqual(select_packet([paused, first, second], previous='first')['session'], 'first')
        self.assertEqual(select_packet([paused, first], previous='paused')['session'], 'first')
        self.assertTrue(select_packet([packet(advertisement=True)])['advertisement'])

    def test_matching_rejects_live_remix_duration_and_end(self):
        self.assertEqual(assess(candidate(), packet()), [])
        for c in [candidate(trackName='Song (Live)'), candidate(trackName='Song Remix'),
                  candidate(artistName='Other'), candidate(duration=200),
                  candidate(syncedLyrics='[03:10]Past end'), candidate(syncedLyrics=None)]:
            self.assertTrue(assess(c, packet()))
        self.assertTrue(assess(candidate(), packet(duration=0)))
        self.assertNotEqual(signature(packet()), signature(packet(album='Live')))

    def test_conflicting_unique_lines_and_duplicates(self):
        a = candidate()
        b = candidate(syncedLyrics='[00:05]One\n[00:06]Two\n[00:07]Three\n[00:08]Four')
        self.assertTrue(timing_conflict([a, b]))
        self.assertFalse(timing_conflict([a, a]))
        self.assertFalse(timing_conflict([a, candidate(syncedLyrics='[00:05]One\n[00:06]One')]))

    def test_storage_atomic_and_activation_not_restored(self):
        with tempfile.TemporaryDirectory() as root:
            atomic_json(Path(root) / 'settings.json', {'audio_enabled': True, 'color': '#fff'})
            store = Store(root)
            self.assertNotIn('audio_enabled', store.settings)
            key = signature(packet())
            store.put_track(key, {'offset': 1.2, 'choice': 42})
            self.assertEqual(Store(root).track(key), {'offset': 1.2, 'choice': 42})

    def test_native_frames_partial_reads_bad_packets_no_injection(self):
        class Partial(io.BytesIO):
            def read(self, size=-1):
                return super().read(min(2, size))
        valid = packet(command='seek', target=120)
        bad = packet(session='../evil')
        wire = b''
        for p in (valid, bad):
            body = json.dumps(p).encode()
            wire += struct.pack('<I', len(body)) + body
        output = io.BytesIO()
        saved = []
        with tempfile.TemporaryDirectory() as root, patch('liris.bridge.atomic_json', side_effect=lambda path, p: saved.append((path, p))):
            serve(Partial(wire), output, root)
        self.assertEqual(len(saved), 1)
        self.assertNotIn('command', saved[0][1])
        self.assertNotEqual(saved[0][1]['session'], valid['session'])
        stream = io.BytesIO(output.getvalue())
        self.assertEqual(json.loads(read_exact(stream, struct.unpack('<I', read_exact(stream, 4))[0])), {'ok': True})
        self.assertEqual(json.loads(read_exact(stream, struct.unpack('<I', read_exact(stream, 4))[0])), {'ok': False})

    def test_extension_identifier_matches_shared_key(self):
        root = Path(__file__).resolve().parents[2]
        identifier = extension_id(root / 'Extension')
        self.assertEqual(len(identifier), 32)
        self.assertTrue(all('a' <= c <= 'p' for c in identifier))


class AudioBoundaryTests(unittest.TestCase):
    def test_import_and_construction_never_start_capture(self):
        with patch('subprocess.Popen') as launch:
            engine = AudioEngine(lambda *a: None, lambda *a: None)
            self.assertFalse(engine.enabled)
            self.assertIsNone(engine.thread)
            engine.stop()
            self.assertFalse(launch.called)

    def test_stop_invalidates_epoch_and_manual_restart_required(self):
        engine = AudioEngine(lambda *a: None, lambda *a: None)
        started = threading.Event()
        def fake_capture(epoch, stop):
            started.set()
            stop.wait(2)
        with patch.object(engine, '_capture', side_effect=fake_capture):
            self.assertTrue(engine.start_manual())
            started.wait(1)
            epoch = engine.epoch
            engine.stop()
            engine.wait(1)
            self.assertFalse(engine.enabled)
            self.assertNotEqual(epoch, engine.epoch)

    def test_suppression_cancels_child_and_rejects_pre_suppression_payload(self):
        engine = AudioEngine(lambda *a: None, lambda *a: None)
        revision = engine.suppression_epoch
        engine.suppress(True)
        engine.suppress(False)
        with patch('subprocess.Popen') as launch:
            engine._recognize(b'fake', 0, engine.epoch, threading.Event(), revision)
            self.assertFalse(launch.called)

    def test_non_loopback_device_fails_closed_without_open(self):
        from unittest.mock import MagicMock
        fake = MagicMock()
        fake.get_default_wasapi_loopback.return_value = {'isLoopbackDevice': False}
        messages = []
        engine = AudioEngine(lambda e, s: messages.append(s), lambda *a: None)
        with patch('pyaudiowpatch.PyAudio', return_value=fake):
            engine._capture(engine.epoch, threading.Event())
        fake.open.assert_not_called()
        self.assertFalse(engine.enabled)
        self.assertIn('bukan WASAPI loopback', messages[-1])

    def test_idle_output_without_callbacks_still_stops_and_closes_stream(self):
        # Load NumPy before timing the capture thread's startup.
        import numpy
        from unittest.mock import MagicMock
        fake = MagicMock()
        fake.get_default_wasapi_loopback.return_value = {'isLoopbackDevice': True, 'defaultSampleRate': 48000,
                                                       'maxInputChannels': 2, 'index': 9, 'name': 'Synthetic output'}
        opened = threading.Event()
        stream = MagicMock()
        def open_stream(**kwargs):
            self.assertTrue(callable(kwargs['stream_callback']))
            self.assertEqual(kwargs['input_device_index'], 9)
            opened.set()
            return stream
        fake.open.side_effect = open_stream
        engine = AudioEngine(lambda *a: None, lambda *a: None)
        with patch('pyaudiowpatch.PyAudio', return_value=fake):
            engine.start_manual()
            try:
                self.assertTrue(opened.wait(5))
            finally:
                engine.stop()
                engine.wait(5)
        self.assertFalse(engine.thread.is_alive())
        stream.close.assert_called_once()
        fake.terminate.assert_called_once()

    def test_late_recognition_reply_after_stop_is_ignored(self):
        from unittest.mock import MagicMock
        matches = []
        engine = AudioEngine(lambda *a: None, lambda *a: matches.append(a))
        entered, release = threading.Event(), threading.Event()
        child = MagicMock()
        child.returncode = 0
        child.poll.return_value = None
        def communicate(*args, **kwargs):
            entered.set()
            release.wait(2)
            return json.dumps({'matched': True, 'title': 'Old', 'artist': 'Old', 'offset': 1}).encode(), b''
        child.communicate.side_effect = communicate
        with patch('subprocess.Popen', return_value=child):
            task = threading.Thread(target=engine._recognize,
                                    args=(b'synthetic', 0, engine.epoch, engine.stop_event, engine.suppression_epoch))
            task.start()
            self.assertTrue(entered.wait(1))
            engine.stop()
            release.set()
            task.join(2)
        self.assertEqual(matches, [])
        child.kill.assert_called()

    def test_in_memory_resampling_matches_shared_worker_contract(self):
        import importlib.util
        import numpy as np
        spec = importlib.util.spec_from_file_location('shared_worker', Path(__file__).resolve().parents[2] / 'backend/shazamio_worker.py')
        worker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(worker)
        # Synthetic silence only. No sound device or network is used.
        encoded = pcm_wav(np.zeros(48000 * 12, dtype=np.float32), 48000)
        self.assertEqual(worker.validate_audio(encoded), 12)


if __name__ == '__main__':
    unittest.main()
