import json
import os
import tempfile
import threading
from pathlib import Path


def data_dir():
    return Path(os.environ.get('LOCALAPPDATA', Path.home())) / 'Liris'


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=path.parent, delete=False) as f:
            name = f.name
            json.dump(value, f, ensure_ascii=False, allow_nan=False)
        os.replace(name, path)
    finally:
        if name and os.path.exists(name):
            os.unlink(name)


def read_json(path, default=None):
    try:
        path = Path(path)
        if path.stat().st_size > 4_000_000:
            return default
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return default


class Store:
    def __init__(self, root=None):
        self.lock = threading.RLock()
        self.root = Path(root) if root else data_dir()
        self.settings = read_json(self.root / 'settings.json', {})
        if not isinstance(self.settings, dict):
            self.settings = {}
        # Audio activation is deliberately never stored or restored.
        self.settings.pop('audio_enabled', None)

    def save(self):
        atomic_json(self.root / 'settings.json', self.settings)

    def track(self, key):
        value = read_json(self.root / 'lyrics' / (key + '.json'), {})
        return value if isinstance(value, dict) else {}

    def put_track(self, key, value):
        with self.lock:
            atomic_json(self.root / 'lyrics' / (key + '.json'), value)

    def update_track(self, key, fields, remove=()):
        with self.lock:
            local = self.track(key)
            for field in remove:
                local.pop(field, None)
            local.update(fields)
            self.put_track(key, local)
            return local
