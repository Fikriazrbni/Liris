"""Packaging entry point; the shared backend remains the recognition implementation."""
import asyncio
import importlib.metadata
import json
import sys
from pathlib import Path

if not getattr(sys, 'frozen', False):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'backend'))

from shazamio_worker import MAX_BYTES, recognize

if __name__ == '__main__':
    try:
        if '--check' in sys.argv:
            from shazamio import Shazam
            print(json.dumps({'ok': True, 'version': importlib.metadata.version('shazamio')}))
        else:
            audio = sys.stdin.buffer.read(MAX_BYTES + 1)
            print(json.dumps(asyncio.run(recognize(audio))))
    except Exception as error:
        print(json.dumps({'matched': False, 'error': type(error).__name__}))
        raise SystemExit(1)
