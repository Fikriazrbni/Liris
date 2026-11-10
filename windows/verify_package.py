"""Real packaged-process verification. No audio device or Shazam recognition."""
import json
import argparse
import os
import queue
import struct
import subprocess
import tempfile
import threading
import time
from pathlib import Path

from liris.bridge import extension_id
from liris.storage import atomic_json, read_json


def main():
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument('--bundle', type=Path, default=root / 'dist' / 'Liris-Windows')
    bundle = parser.parse_args().bundle.resolve()
    evidence = root / '.test-data'
    evidence.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='portable-', dir=evidence) as tmp:
        folder = Path(tmp)
        env = dict(os.environ)
        env['PATH'] = str(Path(os.environ['SystemRoot']) / 'System32')
        env['LOCALAPPDATA'] = str(folder)
        for name in ('PYTHONPATH', 'PYTHONHOME', 'VIRTUAL_ENV', 'QT_PLUGIN_PATH'):
            env.pop(name, None)
        result = subprocess.run([str(bundle / 'LirisWorker.exe'), '--check'], env=env, cwd=folder,
                                capture_output=True, timeout=45, check=True)
        worker = json.loads(result.stdout)
        assert worker['ok'] and worker['version'] == '0.9.0', worker
        origin = 'chrome-extension://' + extension_id(bundle / '_internal' / 'Extension') + '/'
        host = subprocess.Popen([str(bundle / 'LirisBridge.exe'), origin], env=env, cwd=folder,
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        def exchange(packet):
            encoded = json.dumps(packet).encode()
            host.stdin.write(struct.pack('<I', len(encoded)) + encoded)
            host.stdin.flush()
            response_queue = queue.Queue()
            def read():
                header = host.stdout.read(4)
                if len(header) != 4:
                    response_queue.put(RuntimeError('Native host exited: ' + repr(host.stderr.read())))
                    return
                response_queue.put(json.loads(host.stdout.read(struct.unpack('<I', header)[0])))
            threading.Thread(target=read, daemon=True).start()
            response = response_queue.get(timeout=15)
            if isinstance(response, Exception):
                raise response
            return response
        p = {'session': 'tab_9', 'origin': 'youtube-music', 'trackID': 'synthetic', 'title': 'Synthetic test',
             'artist': 'Local fixture', 'album': '', 'position': 10, 'duration': 100,
             'playing': True, 'advertisement': False, 'quantized': False}
        try:
            assert exchange(p) == {'ok': True}
            snapshots = list((folder / 'Liris' / 'Bridge').glob('*.json'))
            assert len(snapshots) == 1
            received = read_json(snapshots[0])
            assert received['title'] == p['title'] and received['session'] != p['session']
            command = dict(received, command='seek', target=42, receivedAt=time.time())
            atomic_json(snapshots[0].with_suffix('.command'), command)
            reply = exchange(p)
            assert reply['command'] == 'seek' and reply['target'] == 42 and reply['trackID'] == p['trackID']
            command = dict(received, command='toggle', trackID='old', receivedAt=time.time())
            atomic_json(snapshots[0].with_suffix('.command'), command)
            assert exchange(p) == {'ok': True}
            assert exchange(dict(p, session='../escape')) == {'ok': False}
            host.stdin.close()
            assert host.wait(timeout=15) == 0
            assert not snapshots[0].exists()
        finally:
            if host.poll() is None:
                host.kill()
                host.wait()
            host.stdout.close()
            host.stderr.close()
        denied = subprocess.run([str(bundle / 'LirisBridge.exe'), 'chrome-extension://invalid/'],
                                env=env, cwd=folder, capture_output=True, timeout=15)
        assert denied.returncode == 1
        report_path = evidence / 'packaged-ui'
        report_path.mkdir(exist_ok=True)
        (report_path / 'smoke.json').unlink(missing_ok=True)
        gui = subprocess.run([str(bundle / 'Liris.exe'), '--smoke-test', str(report_path)], env=env,
                             cwd=folder, timeout=60)
        assert gui.returncode == 0
        report = read_json(report_path / 'smoke.json')
        assert report and report['ok'] and report['audio'] == 'off', report
        summary = {'workerImport': worker, 'nativeHostFraming': 'passed', 'sameTrackCommands': 'passed',
                   'invalidOriginRejected': True, 'pythonAbsentFromPath': True,
                   'foreignWorkingDirectory': True, 'ui': report,
                   'realBrowserTested': False, 'realAudioTested': False, 'realSyncTested': False}
        atomic_json(evidence / 'package-verification.json', summary)
        print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
