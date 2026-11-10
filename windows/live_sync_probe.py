"""Opt-in developer acceptance run: real output, UI clock, packaged Shazam worker.

Never invoked by application startup/build/CI. Persists metadata/timing only.
The user operates Discord and supplies reference positions; no microphone opens.
"""
import argparse
import time
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication
from liris import audio
from liris.storage import Store, atomic_json, read_json
from liris.ui import MainWindow


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--consent-system-output-and-signatures', action='store_true', required=True)
    parser.add_argument('--seconds', type=int, default=180, choices=range(30, 301))
    parser.add_argument('--report', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    report = Path(args.report).resolve()
    report.parent.mkdir(parents=True, exist_ok=True)
    marker = report.with_suffix('.control.json')
    audio.worker_command = lambda: [str(root / 'dist/Liris-Windows/LirisWorker.exe')]
    app = QApplication([])
    window = MainWindow(Store(report.parent / 'sync-store'))
    window.setWindowTitle('Liris • Live sync acceptance (real output, consent granted)')
    window.show()
    started = time.monotonic()
    samples, matches = [], []
    phase = 'baseline'
    def matched(epoch, result, sample_start):
        matches.append(dict(result, elapsed=round(time.monotonic()-started, 3),
                            sampleStart=round(sample_start-started, 3)))
    window.events.match.connect(matched)
    def sample():
        nonlocal phase
        control = read_json(marker, {})
        phase = control.get('phase', phase)
        track = window.track or {}
        item = dict(elapsed=round(time.monotonic()-started, 3), phase=phase,
                    title=track.get('title'), artist=track.get('artist'),
                    position=round(window.clock.value(), 3), playing=window.clock.playing,
                    audioEnabled=window.audio.enabled, audioStatus=window.audio_state,
                    timedLines=len(window.lines), activeLine=window.current_line,
                    lyricsStatus=window.sync_status.text())
        samples.append(item)
        atomic_json(report, {'mode': 'source UI/capture + packaged worker', 'samples': samples,
                            'matches': matches, 'microphoneOpened': False, 'audioPersisted': False})
        print(item, flush=True)
        if control.get('stop') or time.monotonic()-started >= args.seconds:
            timer.stop()
            window.stop_audio()
            window.audio.wait()
            atomic_json(report, {'mode': 'source UI/capture + packaged worker', 'samples': samples,
                        'matches': matches, 'microphoneOpened': False, 'audioPersisted': False,
                        'stopped': not window.audio.thread.is_alive(), 'audioEnabledAfterStop': window.audio.enabled})
            window.quit()
    window.connect_player()
    window.audio.start_manual()
    timer = QTimer(window)
    timer.timeout.connect(sample)
    timer.start(1000)
    app.exec()


if __name__ == '__main__':
    main()
