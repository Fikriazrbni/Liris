# Liris for Windows — development preview

The Windows app lives in `windows/`. The Mac and Windows versions share the browser extension in `Extension/` and the recognition backend in `backend/`.

## Install and run

Run `Liris-Setup-Windows-x64.exe` to install for the current Windows user without administrator rights. Find **Liris** in Start or Search, or use the desktop shortcut if you selected that option. To remove it, open **Settings → Apps → Installed apps → Liris → Uninstall**.

For the portable version, extract the **entire** `Liris-Windows-x64-preview.zip` to a permanent location and open `Liris-Windows/Liris.exe`. Keep the EXE with `_internal/` and both companion executables. The package includes Python, Qt, WASAPI/PortAudio, ShazamIO and their dependencies. End users can run it without Python, pip, the .NET SDK or a manual build.

The initial target is Windows 11 x64. The development preview is unsigned. Clean Windows installations, Windows 10, ARM64, Remote Desktop and other audio devices were outside the initial test coverage. The preview does not establish feature parity or production readiness.

1. In Liris, open **Help → Set Up Extension**. This writes the Liris host manifest and its current-user (HKCU) NativeMessagingHosts keys for Chrome, Brave and Edge.
2. On the browser's Extensions page, enable **Developer mode**, click **Load unpacked** and select the `Extension` folder that Liris opened. This is the same extension used on Mac.
3. Reload YouTube or YouTube Music, then click **Connect**. This route uses neither Apple Events nor a debugging port. It requires no cookies or JavaScript Apple Events permission.
4. Audio recognition stays **Off**. The extension reads playback information directly.
5. For Discord or another app, select **Enable Audio…**, read the privacy notice and confirm. **Stop Audio** is available in the main window, unlocked overlay and tray. Connecting, reconnecting and disconnecting all switch audio off.

After moving the package or switching from portable to installed, run **Set Up Extension** again to update the host path. Registration does not automatically install the extension. To remove the host registration, run `unregister-bridge.ps1`, then remove the extension from the browser.

If the tray is available, closing the window hides the app there. Double-click the tray icon to open the window, or choose **Quit** to exit. Drag or resize the overlay using its Windows frame. You can adjust its color, font size and opacity or lock it for click-through. The tray always offers **Unlock Overlay**.

## Lyrics and timing

- Liris can fetch lyrics automatically from LRCLIB, search manually, select a version or import a UTF-8 LRC file.
- LRC support includes multiple timestamps per line, fractional seconds, header offsets, blank lines and plain text. Plain text stays untimed.
- Positive offsets show lyrics earlier. Offsets are saved by title, artist, album and duration.
- Candidate records are cached for seven days. The app rechecks stored automatic choices and offline fallback records. For HTTP 429 or 503 it honors `Retry-After` rather than retrying every tick.
- Automatic matches require matching title and artist, duration within five seconds, and lyric timestamps no more than three seconds past the end. Titles retain version markers such as “live” and “remix.” Album matches take priority. A timing conflict across four unique matching lines triggers a warning.
- A conflicting manual choice stays visible with a warning and is excluded from automatic preferences. Imported lyrics apply to the active track for the session. Rechecking fetches new candidates. **Use Automatic Selection** clears the saved version and offset for that track.
- The extension sends a heartbeat roughly every 500 ms. It expires after three seconds. A monotonic clock follows pauses, seeks and track changes. Interpolation from whole-second readings stops one second beyond the last reading. Double-click a line to seek when the timeline supports it.
- The audio path adds elapsed time since the sample started to the Shazam offset. Results expire after 35 seconds. Silence holds the clock, while audible output alone cannot identify the track. Audio metadata cannot establish precise pause, seek, track-change or playback-speed behavior, especially with mixed sounds. The UI marks this position as **estimated**.
- Metadata and timestamp agreement do not measure vocal alignment. Real vocal synchronization remains untested. The Windows session verified Discord output capture and recognition of two tracks. [Validation details](VALIDATION.md)

## Privacy and audio

The GUI accepts audio activation only from the manual control and confirmation dialog. CLI arguments and saved settings cannot start capture. WASAPI selects the loopback endpoint for the default output and rejects non-loopback devices without opening a microphone. After changing output devices, you may need to stop and restart audio recognition.

A 12-second float PCM sample is downmixed and resampled to 44,100 Hz mono PCM16, encoded as WAV in RAM, and passed to `LirisWorker.exe` via stdin. The worker uses the shared `backend/shazamio_worker.py` and ShazamIO 0.9.0. The app writes no audio files. Recognition sends a signature to Shazam through the unofficial ShazamIO API. Conversations played through the output can be included in the analysis.

Only one worker runs at a time. A silence gate, request interval, timeout, session epoch and extension-priority epoch bound the work. Active extension playback or an ad cancels the worker and clears the buffer. Capture continues and its indicator stays active until stopped. **Stop Audio** invalidates queued results, terminates the worker and closes the stream. **Stopping** remains visible until shutdown completes.

Lyrics, settings and browser metadata are stored under `%LOCALAPPDATA%\Liris`. LRCLIB receives title, artist and duration or a search query. The app has no telemetry. The native host checks extension origin and frame size, stores no cookies, and routes commands only for the same track with a fresh heartbeat. Sessions are scoped per port so identical tab IDs in two browsers cannot collide.

## Build for development

Use Windows with **64-bit Python 3.13** and a connection to download wheels:

```powershell
cd windows
.\build.ps1
```

`requirements.lock` pins the Windows dependencies, including the shared backend dependencies used on Mac. PyInstaller builds the GUI, native host and worker as three executables sharing one runtime. `package.py` includes an inventory and upstream license notices in the ZIP. Qt uses separate DLLs. [Qt for Python source](https://code.qt.io/cgit/pyside/pyside-setup.git/) · [Qt licensing](https://www.qt.io/licensing/)

The build does not start capture or call Shazam recognition.

```powershell
.venv\Scripts\python.exe -m unittest discover -s tests -v
.venv\Scripts\python.exe main.py
.venv\Scripts\python.exe verify_package.py
```

`verify_package.py` runs the bundle with a PATH that excludes Python and a different working directory. It checks UI startup, reconnect, the overlay, worker imports (`--check`), and native messaging with synthetic fixtures. It neither records nor sends audio. [Validation results and outstanding live tests](VALIDATION.md) · [Architecture](ARCHITECTURE.md)

The developer probe `live_audio_probe.py` runs separately from the app, package, startup, build and CI. Use it only with explicit consent for system-output capture and signature transmission in the current session:

```powershell
.venv\Scripts\python.exe live_audio_probe.py --consent-system-output --recognize --seconds 45 --report .test-data/live.json
```

Without `--recognize`, the probe measures loopback output and suppresses the worker. Its report contains metrics and result metadata and saves no audio samples. It exercises the source capture engine with the packaged `LirisWorker.exe`. Testing the packaged GUI is a separate step.
