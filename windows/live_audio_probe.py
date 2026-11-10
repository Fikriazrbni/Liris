"""Developer-only live acceptance probe. Never invoked by startup/build/CI.

Requires explicit session consent and flags. Writes metrics/results, never samples.
Uses the source capture engine with the packaged recognition executable.
"""
import argparse
import datetime
import json
import threading
import time
from pathlib import Path

from liris import audio
from liris.storage import atomic_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--consent-system-output', action='store_true', required=True)
    parser.add_argument('--recognize', action='store_true', help='Send real signatures to Shazam')
    parser.add_argument('--seconds', type=int, default=40, choices=range(3, 61))
    parser.add_argument('--report', required=True)
    args = parser.parse_args()
    worker = Path(__file__).resolve().parent / 'dist/Liris-Windows/LirisWorker.exe'
    if not worker.is_file():
        parser.error('Build the Windows package first')
    audio.worker_command = lambda: [str(worker)]
    started = time.monotonic()
    statuses, matches, levels = [], [], []
    complete = threading.Event()
    def status(epoch, message):
        entry = {'elapsed': round(time.monotonic() - started, 3), 'epoch': epoch, 'status': message}
        if not statuses or statuses[-1]['status'] != message:
            statuses.append(entry)
            print(json.dumps(entry, ensure_ascii=True), flush=True)
        if 'tidak ada kecocokan' in message or 'gagal' in message or 'error:' in message:
            complete.set()
    def match(epoch, result, sample_started):
        entry = dict(result, epoch=epoch, elapsed=round(time.monotonic() - started, 3),
                     sampleStartElapsed=round(sample_started - started, 3),
                     estimatedPositionAtReply=round(result['offset'] + time.monotonic() - sample_started, 3))
        matches.append(entry)
        print(json.dumps(entry, ensure_ascii=True), flush=True)
        complete.set()
    def level(epoch, value):
        levels.append(value)
    engine = audio.AudioEngine(status, match, level)
    if not args.recognize:
        engine.suppress(True)  # Capture/level only: no worker is launched.
    try:
        engine.start_manual()
        complete.wait(args.seconds)
    finally:
        stop_started = time.monotonic()
        engine.stop()
        engine.wait(30)
        stopped_in = time.monotonic() - stop_started
        report = {'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'mode': 'source capture engine + packaged worker', 'recognitionAllowed': args.recognize,
                  'realSystemOutput': True, 'microphoneOpened': False, 'audioPersisted': False,
                  'elapsed': round(time.monotonic() - started, 3), 'statuses': statuses, 'matches': matches,
                  'levelCallbacks': len(levels), 'peakRms': max(levels, default=0),
                  'audibleCallbacks': sum(x >= 0.001 for x in levels),
                  'stopSeconds': round(stopped_in, 3), 'captureThreadStopped': not engine.thread.is_alive(),
                  'workerStopped': engine.process is None or engine.process.poll() is not None,
                  'audioEnabledAfterStop': engine.enabled}
        atomic_json(Path(args.report), report)
        print(json.dumps({k: v for k, v in report.items() if k not in ('statuses',)}, ensure_ascii=True), flush=True)


if __name__ == '__main__':
    main()
