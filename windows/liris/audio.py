"""WASAPI output loopback only. Construction/import never opens a device.

All sample buffers and WAV encoding stay in RAM. Recognition runs in a killable
child process so Disable/Connect can cancel network work and reject late results.
"""
import io
import json
import math
import queue
import subprocess
import sys
import threading
import time
import wave
from pathlib import Path


def worker_command():
    if getattr(sys, 'frozen', False):
        return [str(Path(sys.executable).parent / 'LirisWorker.exe')]
    return [sys.executable, str(Path(__file__).resolve().parents[1] / 'worker.py')]


def pcm_wav(samples, rate):
    import numpy as np
    from scipy.signal import resample_poly
    divisor = math.gcd(int(rate), 44100)
    mono = resample_poly(samples, 44100 // divisor, int(rate) // divisor)
    pcm = (np.clip(mono, -1, 1) * 32767).astype('<i2').tobytes()
    result = io.BytesIO()
    with wave.open(result, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(44100)
        wav.writeframes(pcm[:12 * 44100 * 2])
    return result.getvalue()


class AudioEngine:
    def __init__(self, on_status, on_match, on_level=lambda *args: None):
        self.on_status, self.on_match, self.on_level = on_status, on_match, on_level
        self.lock = threading.RLock()
        self.epoch = 0
        self.enabled = False
        self.thread = None
        self.stop_event = threading.Event()
        self.suppressed = False
        self.suppression_epoch = 0
        self.process = None

    def status(self, epoch, value):
        if epoch == self.epoch:
            self.on_status(epoch, value)

    def start_manual(self):
        with self.lock:
            if self.thread and self.thread.is_alive():
                return False
            self.epoch += 1
            epoch = self.epoch
            self.enabled = True
            self.stop_event = threading.Event()
            self.status(epoch, 'Starting system audio…')
            self.thread = threading.Thread(target=self._capture, args=(epoch, self.stop_event), daemon=True)
            self.thread.start()
            return True

    def stop(self):
        with self.lock:
            self.enabled = False
            self.epoch += 1  # invalidate queued UI results immediately
            self.stop_event.set()
            if self.process and self.process.poll() is None:
                self.process.kill()
            if self.thread and self.thread.is_alive():
                self.on_status(self.epoch, 'Stopping audio…')
            else:
                self.on_status(self.epoch, 'Off')

    def suppress(self, value):
        with self.lock:
            changed = value != self.suppressed
            if changed:
                self.suppression_epoch += 1
            self.suppressed = value
            if value and self.process and self.process.poll() is None:
                self.process.kill()
            if self.enabled and changed:
                self.status(self.epoch, 'On • recognition paused during browser playback or ads' if value
                            else 'On • waiting for system audio')

    def _recognize(self, payload, start, epoch, stop, suppression_epoch):
        kwargs = {'creationflags': subprocess.CREATE_NO_WINDOW} if sys.platform == 'win32' else {}
        with self.lock:
            if (stop.is_set() or self.suppressed or epoch != self.epoch
                    or suppression_epoch != self.suppression_epoch):
                return
            process = subprocess.Popen(worker_command(), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, **kwargs)
            self.process = process
        try:
            self.status(epoch, 'On • identifying music with ShazamIO…')
            output, _ = process.communicate(payload, timeout=25)
            if (stop.is_set() or self.suppressed or epoch != self.epoch
                    or suppression_epoch != self.suppression_epoch):
                return
            result = json.loads(output)
            if process.returncode or result.get('error'):
                raise ValueError(result.get('error', 'Recognition worker failed'))
            if result.get('matched'):
                if (not isinstance(result.get('title'), str) or not isinstance(result.get('artist'), str)
                        or type(result.get('offset')) not in (float, int)
                        or not math.isfinite(result['offset']) or not 0 <= result['offset'] <= 86400):
                    raise ValueError('Invalid recognition result')
                self.on_match(epoch, result, start)
                self.status(epoch, 'On • track identified, position estimated')
            else:
                self.status(epoch, 'On • no match')
        except (ValueError, OSError, subprocess.TimeoutExpired) as error:
            self.status(epoch, 'On • recognition failed: ' + type(error).__name__)
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()
            with self.lock:
                if self.process is process:
                    self.process = None

    def _capture(self, epoch, stop):
        stream = None
        port = None
        recognition = None
        failure = None
        try:
            import numpy as np
            import pyaudiowpatch as pa
            # No default input / microphone fallback is permitted.
            port = pa.PyAudio()
            device = port.get_default_wasapi_loopback()
            if not device.get('isLoopbackDevice'):
                raise RuntimeError('Capture canceled: device does not support WASAPI loopback')
            rate = int(device['defaultSampleRate'])
            channels = int(device['maxInputChannels'])
            if not 1 <= channels <= 32 or not 8000 <= rate <= 192000:
                raise RuntimeError('Unsupported output format')
            block = max(1, rate // 10)
            if stop.is_set():
                return
            pending = queue.Queue(maxsize=20)
            overflow = threading.Event()
            def callback(data, frames, timing, status):
                if stop.is_set():
                    return None, pa.paAbort
                if status:
                    overflow.set()
                try:
                    pending.put_nowait((data, time.monotonic() - frames / rate))
                except queue.Full:
                    overflow.set()
                return None, pa.paContinue
            stream = port.open(format=pa.paFloat32, channels=channels, rate=rate, input=True,
                               input_device_index=device['index'], frames_per_buffer=block,
                               stream_callback=callback)
            self.status(epoch, 'On • output: ' + device['name'])
            chunks = []
            count = 0
            started = None
            next_request = 0
            buffer_revision = self.suppression_epoch
            while not stop.is_set():
                if overflow.is_set():
                    raise RuntimeError('Audio buffer overflow. Restart audio recognition to reset timing')
                try:
                    data, block_started = pending.get(timeout=0.2)
                except queue.Empty:
                    continue  # Stop remains responsive even when the output is idle.
                samples = np.frombuffer(data, dtype='<f4').reshape(-1, channels).mean(axis=1)
                level = float(np.sqrt(np.mean(samples ** 2)))
                self.on_level(epoch, level)
                if buffer_revision != self.suppression_epoch:
                    chunks.clear()
                    count = 0
                    started = None
                    buffer_revision = self.suppression_epoch
                if self.suppressed or (recognition and recognition.is_alive()) or time.monotonic() < next_request:
                    chunks.clear()
                    count = 0
                    started = None
                    continue
                if level < 0.001:
                    if started is None:
                        self.status(epoch, 'On • silent, waiting for system audio')
                        continue
                if started is None:
                    started = block_started
                    self.status(epoch, 'On • collecting a 12-second sample in memory')
                chunks.append(samples)
                count += len(samples)
                if count >= rate * 12:
                    joined = np.concatenate(chunks)[:rate * 12]
                    chunks.clear()
                    count = 0
                    if float(np.sqrt(np.mean(joined ** 2))) >= 0.001:
                        payload = pcm_wav(joined, rate)
                        recognition = threading.Thread(target=self._recognize,
                                                       args=(payload, started, epoch, stop, self.suppression_epoch), daemon=True)
                        recognition.start()
                        next_request = time.monotonic() + 20
                    started = None
            chunks.clear()
        except Exception as error:
            failure = type(error).__name__ + ': ' + str(error)
        finally:
            # Keep the state in "stopping" until device AND child worker are gone.
            if stream:
                stream.close()
            if port:
                port.terminate()
            with self.lock:
                if self.process and self.process.poll() is None:
                    self.process.kill()
            if recognition:
                recognition.join(timeout=28)
            with self.lock:
                self.enabled = False
                self.on_status(self.epoch, ('Off • error: ' + failure) if failure and epoch == self.epoch else 'Off')

    def wait(self, timeout=30):
        if self.thread:
            self.thread.join(timeout)
