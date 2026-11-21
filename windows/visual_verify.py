"""Offline visual fixtures. Separate from production startup; never captures audio."""
import json
import os
import sys
from pathlib import Path
from unittest.mock import patch
from PySide6.QtCore import Qt, QPoint
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication
from liris.ui import MainWindow
from liris.storage import Store
from liris.core import parse_lrc, signature
from liris.presentation import present, show_page


def main():
    app = QApplication([])
    folder = Path('.test-data/visual') / os.environ.get('QT_SCALE_FACTOR', '1')
    folder.mkdir(parents=True, exist_ok=True)
    with patch('liris.audio.AudioEngine.start_manual', side_effect=AssertionError('No capture in visual fixtures')), \
         patch('liris.lyrics.LyricsClient.request', side_effect=AssertionError('No network in visual fixtures')):
        w = MainWindow(Store(folder / 'store'))
        w.poll.stop()
        w.presentation_timer.stop()
        w.demo_badge.show()
        track = dict(title='Evening Room', artist='Liris Studio', album='Studio Demo', duration=50,
                     origin='demo', session='demo', trackID='demo', position=16, playing=False)
        lyric = '[00:00]Let the world turn for a moment\n[00:12]We hear the same old story\n[00:22]Every word finds its note\n[00:35]In the room we call our own'
        c = dict(id=1, trackName=track['title'], artistName=track['artist'], duration=50, syncedLyrics=lyric)
        report = []
        for width, height in [(1220, 790), (940, 640)]:
            w.resize(width, height)
            w.show()
            app.processEvents()
            w.resize(width, height)
            app.processEvents()
            for state in ['off', 'active', 'starting', 'stopping', 'suppressed', 'uncertain', 'empty', 'loading', 'error', 'appearance', 'guide', 'search']:
                w.track = track.copy()
                w.track_key = signature(track)
                w.set_lyrics(c)
                w.clock.update(track)
                w.current_line = 1
                w.lyrics_list.setCurrentRow(1)
                w.sync_status.setText('Visual demo · original lyrics. Vocal timing is untested.')
                w.audio.enabled = state in ('active', 'starting', 'suppressed')
                audio_text = {'active': 'On • visual simulation', 'starting': 'Starting • visual simulation',
                              'stopping': 'Stopping • visual simulation', 'suppressed': 'On • recognition paused during browser playback or ads (simulation)'}
                w.audio_status(w.audio.epoch, audio_text.get(state, 'Off'))
                w.audio_enable.setEnabled(False)
                if state == 'uncertain':
                    w.sync_status.setText('⚠ Check lyric timing. Versions disagree. Vocal timing is unverified.')
                if state in ('empty', 'loading', 'error'):
                    w.track = None
                    w.set_lyrics(None)
                    w.sync_status.setText({'empty': 'No lyrics yet. Play a track, then click Connect.', 'loading': 'Looking for lyrics…', 'error': 'Network unavailable. Try searching again or import an LRC file.'}[state])
                page = {'appearance': 2, 'guide': 3, 'search': 1}.get(state, 0)
                show_page(w, page)
                if state == 'search':
                    w.candidates = [c]
                    w.populate_versions()
                    w.query.setText('Evening Room · Liris Studio')
                present(w)
                app.processEvents()
                QTest.qWait(30)
                if w.lines:
                    w.lyrics_list.scrollToItem(w.lyrics_list.item(1), w.lyrics_list.ScrollHint.PositionAtCenter)
                if width < 1100 and page == 0 and w.lines:
                    w.stage_scroll.ensureWidgetVisible(w.lyrics_list)
                app.processEvents()
                w.setWindowState(Qt.WindowState.WindowNoState)
                w.resize(width, height)
                app.processEvents()
                assert w.width() == width and w.height() == height, (w.size(), width, height)
                for control in [w.page_heading, w.audio_banner, w.audio_stop if state in audio_text else w.audio_enable] + ([w.play, w.timeline] if page == 0 else []):
                    top = control.mapTo(w, QPoint(0, 0))
                    assert top.x() >= 0 and top.y() >= 0 and top.x()+control.width() <= w.width() and top.y()+control.height() <= w.height(), (state, control, top)
                w.grab().save(str(folder / f'{width}-{state}.png'))
                report.append({'size': [width, height], 'state': state, 'dpr': w.devicePixelRatioF(), 'primaryBounds': 'passed'})
            w.audio.enabled = True
            w.audio_status(w.audio.epoch, 'On • visual simulation')
            present(w)
            w.overlay.previous_line.setText('Let the world turn for a moment')
            w.overlay.text.setText('We hear the same old story')
            w.overlay.next_line.setText('Every word finds its note')
            w.overlay.title.setText('LIRIS / Evening Room · DEMO · NO AUDIO')
            w.overlay.resize(800, 230)
            w.overlay.show()
            app.processEvents()
            w.overlay.grab().save(str(folder / 'overlay.png'))
            w.overlay.set_locked(True)
            app.processEvents()
            assert w.overlay.indicator.isVisible() and not w.overlay.stop.isVisible()
            w.overlay.grab().save(str(folder / 'overlay-locked.png'))
            w.overlay.set_locked(False)
            w.overlay.hide()
        show_page(w, 1)
        w.query.setFocus()
        app.processEvents()
        QTest.keyClick(w.query, Qt.Key.Key_Tab)
        assert app.focusWidget() is not w.query
        w.audio.enabled = False
        assert w.audio.thread is None
        (folder / 'report.json').write_text(json.dumps({'renders': report, 'tabNavigation': 'passed', 'captureStarted': False, 'networkUsed': False}, indent=2))
        w.quit()
    print(str(folder / 'report.json'))


if __name__ == '__main__':
    main()
