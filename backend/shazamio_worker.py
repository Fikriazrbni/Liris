"""One bounded recognition request. WAV travels via stdin; audio is never persisted."""
import asyncio
import io
import json
import math
import sys
import wave

MAX_BYTES = 1_200_000

def validate_audio(data):
    if len(data) > MAX_BYTES:
        raise ValueError('Audio chunk exceeds limit')
    with wave.open(io.BytesIO(data), 'rb') as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (1, 2, 44100):
            raise ValueError('Expected mono PCM16 at 44100 Hz')
        seconds = wav.getnframes() / 44100
        if not 3 <= seconds <= 12.1:
            raise ValueError('Audio chunk must be between 3 and 12 seconds')
    return seconds

def extract_match(response):
    track = response.get('track') or {}
    matches = response.get('matches') or []
    if not track.get('title') or not track.get('subtitle') or not matches:
        return {'matched': False}
    offset = float(matches[0].get('offset', -1))
    if not math.isfinite(offset) or not 0 <= offset <= 86400:
        raise ValueError('Invalid recognition offset')
    return {'matched': True, 'title': str(track['title'])[:1000],
            'artist': str(track['subtitle'])[:1000], 'offset': offset}

async def recognize(data):
    from shazamio import Shazam
    validate_audio(data)
    async with Shazam() as shazam:
        response = await asyncio.wait_for(shazam.recognize(data), timeout=18)
    return extract_match(response)

if __name__ == '__main__':
    try:
        if '--check' in sys.argv:
            import importlib.metadata
            from shazamio import Shazam
            print(json.dumps({'ok': True, 'provider': 'shazamio', 'version': importlib.metadata.version('shazamio')}))
        else:
            audio = sys.stdin.buffer.read(MAX_BYTES + 1)
            print(json.dumps(asyncio.run(recognize(audio))))
    except Exception as error:
        print(json.dumps({'matched': False, 'error': type(error).__name__}))
        sys.exit(1)
