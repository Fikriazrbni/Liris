"""Chromium native messaging, wire-compatible with Extension/. No audio APIs."""
import base64
import hashlib
import json
import os
import struct
import sys
import time
import uuid
from pathlib import Path

from liris.core import fresh_packet, valid_packet
from liris.storage import atomic_json, data_dir, read_json

HOST = 'id.local.liris.bridge'


def extension_id(folder):
    manifest = json.loads((Path(folder) / 'manifest.json').read_text())
    digest = hashlib.sha256(base64.b64decode(manifest['key'])).hexdigest()[:32]
    return ''.join(chr(97 + int(n, 16)) for n in digest)


def read_exact(stream, size):
    result = bytearray()
    while len(result) < size:
        part = stream.read(size - len(result))
        if not part:
            return None
        result.extend(part)
    return bytes(result)


def serve(input_stream, output_stream, directory):
    directory = Path(directory)
    prefix = uuid.uuid4().hex[:12]
    written = set()
    try:
        while header := read_exact(input_stream, 4):
            length, = struct.unpack('<I', header)
            if not 0 < length <= 65536:
                break
            body = read_exact(input_stream, length)
            if body is None:
                break
            reply = {'ok': False}
            try:
                p = json.loads(body)
                if valid_packet(p):
                    p = {k: p[k] for k in ('session', 'origin', 'trackID', 'title', 'artist', 'album',
                                           'position', 'duration', 'playing', 'advertisement', 'quantized') if k in p}
                    # Tab IDs overlap across browsers. Scope each native port to its process.
                    p['session'] = prefix + '_' + p['session'][:80]
                    p['receivedAt'] = time.time()
                    filename = directory / (p['session'] + '.json')
                    atomic_json(filename, p)
                    written.add(filename)
                    reply = {'ok': True}
                    command_file = directory / (p['session'] + '.command')
                    command = read_json(command_file, {})
                    if command_file.exists():
                        command_file.unlink(missing_ok=True)
                    if (fresh_packet(command) and command['trackID'] == p['trackID']
                            and command.get('command') in ('toggle', 'seek')):
                        target = command.get('target', 0)
                        if type(target) in (int, float) and 0 <= target <= p['duration']:
                            reply.update(command=command['command'], target=target, trackID=p['trackID'])
            except (ValueError, OSError, TypeError, KeyError):
                pass
            encoded = json.dumps(reply, allow_nan=False).encode()
            output_stream.write(struct.pack('<I', len(encoded)) + encoded)
            output_stream.flush()
    finally:
        for path in written:
            path.unlink(missing_ok=True)


def register(host_exe, extension_folder):
    import winreg
    host_exe = Path(host_exe).resolve()
    if not host_exe.is_file():
        raise FileNotFoundError('LirisBridge.exe belum tersedia. Jalankan paket hasil build.')
    origin = 'chrome-extension://' + extension_id(extension_folder) + '/'
    manifest_path = data_dir() / 'NativeMessaging' / (HOST + '.json')
    atomic_json(manifest_path, {'name': HOST, 'description': 'Liris Windows playback bridge',
                              'path': str(host_exe), 'type': 'stdio', 'allowed_origins': [origin]})
    for browser in ('Google\\Chrome', 'BraveSoftware\\Brave-Browser', 'Microsoft\\Edge'):
        key_path = 'Software\\' + browser + '\\NativeMessagingHosts\\' + HOST
        with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_WRITE) as key:
            winreg.SetValueEx(key, '', 0, winreg.REG_SZ, str(manifest_path))
    return origin


def main():
    # Chrome supplies the calling extension origin. Do not accept an arbitrary caller.
    folder = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parents[2])) / 'Extension'
    expected = 'chrome-extension://' + extension_id(folder) + '/'
    if len(sys.argv) < 2 or sys.argv[1] != expected:
        return 1
    if os.name == 'nt':
        import msvcrt
        msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
        msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
    serve(sys.stdin.buffer, sys.stdout.buffer, data_dir() / 'Bridge')
    return 0
