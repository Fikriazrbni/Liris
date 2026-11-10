# Windows validation — 10 November 2026 (Asia/Jakarta)

Branch `codex/windows-app`. Development preview, Windows 11 x64 build 26300,
Python build runtime 3.13.5. No AGENTS.md found in the repo or checked parent folders.
Mac implementation, release v0.4.3 assets and Homebrew remain unchanged.

## Feature mapping and evidence

| Requirement | Implementation | Evidence / remaining validation |
| --- | --- | --- |
| YouTube/YouTube Music | Same Extension; Windows native messaging host; current-user registry setup | Wire fixtures and packaged-process protocol; real browser setup still pending |
| Discord/other output | WASAPI default output loopback → RAM WAV → shared ShazamIO backend | Format/import/mock boundaries; actual device capture and real recognition NOT run |
| LRCLIB/manual/import/cache/versions/offset | Implemented in Windows UI/core | Unit/UI fixtures and real HTTP search; broader catalogue/version evaluation pending |
| Sync pause/seek/song change | Monotonic clock, heartbeat expiry, bounded quantized timing, stale-result cancellation | Synthetic UI/clock tests; real player/vocal synchronization NOT tested |
| Version/duration matching | Exact normalized title/artist, duration bounds, timestamps, album preference, unique-line timing conflict warning | Unit fixtures; unknown audio duration explicitly unverified |
| Overlay and tray | Topmost resizable window, font/color/opacity, click-through, tray unlock/stop | Qt render and native extended-style assertions; manual multi-display/fullscreen usability pending |
| Clear audio indicator / Stop | Main/overlay/tray, orange active/stopping, explicit Stop | Mock/unit/UI boundaries; real stream shutdown pending permission |
| Audio off on startup/Connect/reconnect | No persisted activation or activation CLI; explicit dialog Yes only | UI tests and packaged startup/reconnect smoke |
| Standalone package | Portable ZIP with Python/Qt/WASAPI/ShazamIO, three executables and license notices | Local build and packaged verification; clean machine/SmartScreen/signing pending |

## Commands

```powershell
cd windows
.venv\Scripts\python.exe -m unittest discover -s tests -v
.venv\Scripts\python.exe -m PyInstaller --noconfirm Liris.spec
.venv\Scripts\python.exe verify_package.py
.venv\Scripts\python.exe package.py
```

From repo root:

```powershell
node --test scripts/test-auto-extension.cjs scripts/browser-probe.test.cjs
windows/.venv/Scripts/python.exe -m unittest discover -s Tests/Backend -v
```

Windows tests cover parsing, metadata/duration/end-of-song rejection, unique-line
timing conflicts, clock seek/pause/quantization/expiry, bridge framing, invalid
origins/path traversal, session isolation, offline/rate-limit handling, cache choices,
audio opt-in, loopback-only fail-closed behavior, stale recognition cancellation,
UI request generation, and native overlay styles. All audio samples in automated
tests are synthetic zeros. Devices are mocked, never opened.

Shared regression checks: **17 JavaScript tests** and **5 backend tests** passed.
Windows suite: **31 tests passed**, including actual Qt widgets and native
WS_EX_TOPMOST/WS_EX_TRANSPARENT assertions. These native-style assertions verify
window configuration, not manual click routing through arbitrary applications.
No Swift toolchain is installed on this Windows machine; Mac Swift tests were not run.
Shared source directories have no changes.

Real LRCLIB HTTP search `Coldplay Yellow` succeeded, returning 20 candidates with
synced lyrics. Only counts were printed. This proves API connectivity, not timing.

Packaged worker import (`--check`) reports ShazamIO **0.9.0**. Packaged native host
successfully exchanges framed snapshots and same-track commands, rejects wrong
origin/unsafe session names, and removes its snapshot on exit. Packaged GUI renders,
Connect/reconnect keep audio off, WASAPI library imports without creating a device,
and synthetic resampling succeeds. No real browser participated in these checks.

Packaging regression found and fixed: the developer PATH exposed Poppler's ICU DLL,
which PyInstaller collected in place of the Windows ICU API and broke QtCore import.
The spec now isolates DLL discovery from unrelated developer tools and includes one
compatible MSVC runtime from the Qt wheel for all three entry points. The clean
bundle verifier is the acceptance gate for this fix.

Package verifier writes machine-readable evidence to
`windows/.test-data/package-verification.json`, with UI images in
`windows/.test-data/packaged-ui/`. It restricts PATH to System32, removes Python/Qt
environment overrides, and uses a foreign working directory. A machine with system
Python still exists underneath this test, so this is not a clean-machine test.

## Not tested with live inputs

- Extension installation/registry discovery and YouTube/YouTube Music playback in
  Chrome, Brave or Edge on this Windows session.
- Real WASAPI stream, audio level/silence behavior, default-device switch/unplug,
  cancellation during device startup/active read, and CPU usage over long sessions.
- ShazamIO request with real audio/signature, Discord music, mixed conversation,
  no-match/rate limit from Shazam, recognition latency and real song offset.
- Real pause/seek/song changes, vocal alignment, lyrics version correctness.
- Windows clean install, Windows 10/ARM64, multiple displays/fullscreen games,
  packaged CI run, signing, installer/update flow, public Windows release.

These are explicit remaining work toward feature parity. Audio recognition cannot
provide exact transport state; source pause/seek remains controlled in the original
application. No Windows media-session adapter is included yet.

## Next live acceptance steps

1. Launch the package, confirm Audio Mati; Connect and reconnect must keep it off.
2. Set up the existing extension; test YouTube and YouTube Music play/pause, seek
   backwards/forwards, ads, track changes, stale tabs and two browser sessions.
3. Compare manual/LRCLIB/LRC versions and offsets with the actual player and vocals.
4. **Ask the user for permission in this Windows session before opening any real
   capture stream or sending real signatures to Shazam.** After permission, use
   a known music-only output first; verify active indicator, Stop, reconnect off,
   extension priority, output-device failure, and absence of audio files.
5. Repeat on a clean Windows x64 machine; then decide signing/distribution readiness.

No real capture, microphone input, or Shazam recognition request was used during
the automated verification. No Windows release was published and no merge to main
was performed.
