"""Actual Qt widgets; synthetic packets/lyrics only, no audio or network."""
import ctypes
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QApplication, QMessageBox

from liris.core import signature
from liris.storage import Store, atomic_json
from liris.ui import MainWindow
from test_core import candidate, packet


class UiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setQuitOnLastWindowClosed(False)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.window = MainWindow(Store(self.temp.name))
        self.window.poll.stop()
        self.window.submit = lambda *a, **kw: None

    def tearDown(self):
        self.window.quit()
        self.window.deleteLater()
        self.app.processEvents()
        self.temp.cleanup()

    def test_start_connect_reconnect_disconnect_never_open_audio(self):
        with patch.object(self.window.audio, 'start_manual') as start:
            self.assertFalse(self.window.audio.enabled)
            self.window.connect_player()
            self.window.connect_player()
            self.window.disconnect_player()
            start.assert_not_called()
            self.assertIsNone(self.window.audio.thread)

    def test_activation_requires_explicit_yes_and_disconnect_invalidates_late_match(self):
        self.window.connect_player()
        with patch.object(QMessageBox, 'question', return_value=QMessageBox.StandardButton.No), \
                patch.object(self.window.audio, 'start_manual') as start:
            self.window.enable_audio()
            start.assert_not_called()
        with patch.object(QMessageBox, 'question', return_value=QMessageBox.StandardButton.Yes), \
                patch.object(self.window.audio, 'start_manual') as start:
            self.window.enable_audio()
            start.assert_called_once()
        epoch = self.window.audio.epoch
        self.window.disconnect_player()
        self.window.audio_match(epoch, {'title': 'Old', 'artist': 'Old', 'offset': 1}, time.monotonic())
        self.assertIsNone(self.window.track)

    def test_packet_seek_pause_change_ad_and_expiry(self):
        self.window.connect_player()
        path = Path(self.temp.name) / 'Bridge' / 'tab_1.json'
        atomic_json(path, packet())
        self.window.tick()
        self.assertEqual(self.window.track['title'], 'Song')
        atomic_json(path, packet(position=40, playing=False))
        self.window.tick()
        self.assertEqual(self.window.clock.value(), 40)
        atomic_json(path, packet(trackID='new', title='New', position=0))
        self.window.tick()
        self.assertEqual(self.window.track['title'], 'New')
        atomic_json(path, packet(advertisement=True))
        self.window.tick()
        self.assertIsNone(self.window.track)
        self.assertTrue(self.window.audio.suppressed)
        atomic_json(path, packet(receivedAt=time.time() - 10))
        self.window.tick()
        self.assertIsNone(self.window.packet)

    def test_old_network_result_cannot_replace_manual_or_new_track(self):
        self.window.use_track(packet())
        old_generation = self.window.generation
        self.window.use_track(packet(title='Different'))
        self.window.got_result(old_generation, 'resolve', (candidate(), [], 'old'))
        self.assertEqual(self.window.lines, [])
        self.assertNotEqual(self.window.sync_status.text(), 'old')

    def test_offset_and_safe_version_persist_but_unsafe_choice_does_not(self):
        self.window.use_track(packet())
        self.window.offset.setValue(1.2)
        self.window.candidates = [candidate()]
        self.window.populate_versions()
        self.window.choose_version()
        key = signature(packet())
        self.assertEqual(self.window.store.track(key)['choice'], 1)
        self.assertEqual(self.window.store.track(key)['offset'], 1.2)
        self.window.candidates = [candidate(id=9, duration=999)]
        self.window.populate_versions()
        self.window.choose_version()
        self.assertEqual(self.window.store.track(key)['choice'], 1)
        self.assertIn('durasi berbeda', self.window.sync_status.text())

    def test_overlay_native_styles_and_tray_emergency_stop(self):
        overlay = self.window.overlay
        overlay.show()
        overlay.set_locked(True)
        self.app.processEvents()
        self.assertTrue(overlay.windowFlags() & Qt.WindowType.WindowTransparentForInput)
        # Actual Windows extended styles, without using a sound device.
        user32 = ctypes.windll.user32
        user32.GetWindowLongW.argtypes = [ctypes.c_void_p, ctypes.c_int]
        user32.GetWindowLongW.restype = ctypes.c_long
        style = user32.GetWindowLongW(int(overlay.winId()), -20)
        self.assertTrue(style & 0x20, f'WS_EX_TRANSPARENT absent: {style:x}')
        self.assertTrue(style & 0x8, f'WS_EX_TOPMOST absent: {style:x}')
        overlay.set_locked(False)
        self.app.processEvents()
        style = user32.GetWindowLongW(int(overlay.winId()), -20)
        self.assertFalse(style & 0x20)
        actions = self.window.tray.contextMenu().actions()
        stop = next(a for a in actions if a.text() == 'Matikan audio')
        with patch.object(self.window.audio, 'stop') as halt:
            stop.trigger()
            halt.assert_called_once()


if __name__ == '__main__':
    unittest.main()
