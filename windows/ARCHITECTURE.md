# Windows architecture

## Stack decision

Mesin inspeksi: Windows 11 x64 (build 26300), Python 3.13.5 tersedia; .NET SDK tidak
tersedia. PySide6/Qt Widgets menyediakan UI Windows, tray, topmost dan input-transparent
window tanpa memport SwiftUI. PyAudioWPatch mengekspos default WASAPI output loopback.
NumPy/SciPy melakukan downmix/resampling di RAM; Python berbagi backend ShazamIO
yang sudah ada. PyInstaller membuat runtime redistributable tanpa Python pengguna.

Referensi primer yang diperiksa:

- [Qt deployment](https://doc.qt.io/qtforpython-6/deployment/)
- [PyAudioWPatch](https://github.com/s0d3s/PyAudioWPatch)
- [Chromium native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)
- [LRCLIB API](https://lrclib.net/docs)

## Components

| File | Responsibility |
| --- | --- |
| `main.py`, `liris/ui.py` | UI, tray, overlay, generation tokens, player polling, consent |
| `liris/core.py` | Wire validation, track signature, LRC, clock, version/timing assessment |
| `liris/storage.py` | Atomic JSON, merge updates under lock, local settings/cache |
| `liris/lyrics.py` | Bounded HTTPS, Retry-After, LRCLIB selection and offline fallback |
| `host.py`, `liris/bridge.py` | Native framing, HKCU setup, scoped sessions, control exchange |
| `liris/audio.py` | Opt-in WASAPI capture, RAM WAV, cancelable worker and expiry |
| `worker.py` | Packaging entry for unchanged shared ShazamIO backend |
| `Liris.spec`, `package.py` | Portable runtime, three EXEs, notices and ZIP |

The GUI polls local bridge files. No local HTTP listener or browser automation
debugging connection is used. A browser-started native host receives only the shared
extension's permitted origin and writes validated snapshots atomically. The GUI
issues same-track, short-lived commands back through the next heartbeat.

Networking runs outside the UI thread. A generation identifies each lyric request
and invalidates results after manual choice/import or track change. Cache updates
merge current local preferences to preserve offsets changed during network requests.
Recognition uses a separate process so Stop can terminate the network request.

## Audio state boundaries

Construction → Off. Connect/reconnect/disconnect → Stop → Off. Only explicit UI
activation with a Yes response → Starting → Active. Error/Stop → Stopping → Off.
Activation is never persisted. CLI smoke mode cannot activate audio.

The main epoch invalidates any recognition/level/status callback from an earlier
audio session. A separate suppression epoch invalidates audio payloads/results
across transitions into and out of extension priority. Capture uses only a validated
`isLoopbackDevice` endpoint; no code opens the default microphone.

Capture and recognition have different statuses: extension priority discards sample
buffers and kills recognition, while output capture remains active until Stop.
Indicators remain orange in that state. Samples/WAV live in Python memory and child
stdin only; only lyrics, preferences and browser metadata are persisted.

## Known differences from Mac

No Apple Events/Spotify/Apple Music adapter: browser extension plus audio fallback.
No native Windows media-session adapter yet. Audio source does not provide exact
transport state or duration. Unknown duration permits a metadata-only provisional
lyric result, clearly marked unverified and never saved as a safe preferred version.
No claim of vocal alignment or clean-machine compatibility. Default FxSound output
loopback and recognition were subsequently validated with Discord on this machine;
see VALIDATION.md for the scope and measured results.
