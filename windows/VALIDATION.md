# Windows validation — 10 November 2026 (Asia/Jakarta)

Branch `codex/windows-app`. Development preview, Windows 11 x64 build 26300,
Python build runtime 3.13.5. No AGENTS.md found in the repo or checked parent folders.
Mac implementation, release v0.4.3 assets and Homebrew remain unchanged.

## Feature mapping and evidence

| Requirement | Implementation | Evidence / remaining validation |
| --- | --- | --- |
| YouTube/YouTube Music | Same Extension; Windows native messaging host; current-user registry setup | Wire fixtures and packaged-process protocol; real browser setup still pending |
| Discord/other output | WASAPI default output loopback → RAM WAV → shared ShazamIO backend | Real Discord output: LosT/BMTH and Starlight/Muse confirmed by user; other devices/apps pending |
| LRCLIB/manual/import/cache/versions/offset | Implemented in Windows UI/core | Unit/UI fixtures and real HTTP search; broader catalogue/version evaluation pending |
| Sync pause/seek/song change | Monotonic clock, heartbeat expiry, bounded quantized timing, stale-result cancellation | Synthetic UI/clock tests; real player/vocal synchronization NOT tested |
| Version/duration matching | Exact normalized title/artist, duration bounds, timestamps, album preference, unique-line timing conflict warning | Unit fixtures; unknown audio duration explicitly unverified |
| Overlay and tray | Topmost resizable window, font/color/opacity, click-through, tray unlock/stop | Qt render and native extended-style assertions; manual multi-display/fullscreen usability pending |
| Clear audio indicator / Stop | Main/overlay/tray, orange active/stopping, explicit Stop | Real probe stop 0.197 s; packaged GUI Stop returned to Audio Mati; active tray/overlay stop still pending |
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
Windows suite: **35 tests passed**, including actual Qt widgets and native
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

## Real Discord acceptance — 10 November 2026, approximately 23:04–23:15 WIB

The user explicitly authorized system-output capture and signature transmission in
this Windows session and stated that music was playing through Discord. The chosen
endpoint was **Speakers (FxSound Audio Enhancer) [Loopback]**, stereo, 48000 Hz,
`isLoopbackDevice=true`. No microphone device was selected or opened by this code.

1. A bounded developer probe used the source AudioEngine and the **packaged**
   `LirisWorker.exe`. It recognized **LosT — Bring Me The Horizon** at 13.872 seconds
   from activation. The user confirmed the song. There were 136 audio callbacks,
   all above the audible gate; peak block RMS 0.118644. The reported match offset
   was 110.320 s; estimated position at reply 123.934 s. That position was NOT
   compared to a trusted source clock or vocals.
2. Probe Stop completed in **0.197 seconds**; capture thread and worker had both
   exited, and enabled was false. Metrics are in `.test-data/live-discord-1.json`.
   The probe never writes WAV/PCM files; only this JSON report is persisted.
3. The actual packaged GUI was opened. Startup and Connect showed **Audio Mati**.
   Its manually activated capture recognized **Starlight — Muse**; the user
   confirmed Discord had changed to that song. The active indicator and approximate
   clock were observed through Windows accessibility state. Clicking **Matikan
   audio** showed Menghentikan then **Audio Mati**. A subsequent Connect remained off.
4. Automatic lyric retrieval in that GUI session hit a **TLS handshake timeout**.
   A later manual search from the same package returned **20 candidates**. A direct
   real LRCLIB resolve for the recognized metadata then returned **21 candidates**,
   selected id 76769 / Starlight / Muse / 240 s, with **42 timed lines**, in **0.788 s**.
   This last resolve used the source client, not the rebuilt packaged GUI.

Two implementation problems were found and corrected after the live run:

- A failure in `/get` prevented `/search` fallback, and a search failure discarded
  a usable exact result. The two bounded requests now retain partial successes;
  Retry-After still prevents a second HTTP call after a rate limit. Three regressions
  cover exact timeout, search timeout and rate-limit behavior. The transient TLS
  failure itself was not attributed to a specific network/root cause.
- Stop/reconnect left stale source/error text in the empty player. Clearing a track
  now resets source, lyric status and displayed position; a UI regression covers it.

The first capture attempt was rejected by automatic approval review because it
interpreted local worker WAV input as a raw-audio upload. Installed ShazamIO source
was inspected: `recognize_bytes` constructs the signature locally, and
`send_recognize_request_v2` POSTs signature JSON. Re-review accepted this evidence;
the live run followed. No raw WAV was passed to the HTTP request by the inspected
ShazamIO Python path. No further user permission was needed or inferred.

Capture was stopped at the end. The GUI test process was then closed for rebuilding.
No public release, push or merge was performed.

## Still not tested with live inputs

- Extension installation/registry discovery and YouTube/YouTube Music playback in
  Chrome, Brave or Edge on this Windows session.
- Other WASAPI endpoints, silence/pause behavior, default-device switch/unplug,
  cancellation during device startup, and CPU usage over long sessions.
- Mixed conversation, no-match/rate limit from Shazam, exact real song offset,
  and Stop while an HTTP response is in flight.
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
4. Session permission was granted and real Discord capture/recognition/Stop tested.
   Continue pending extension priority, silence/seek and output-device failure tests
   within that authorization; obtain fresh consent in a future Windows session.
5. Repeat on a clean Windows x64 machine; then decide signing/distribution readiness.

The unit/smoke verification remains synthetic. The separate live acceptance above
used real output capture/signatures after permission; no microphone input was opened.
No Windows release was published and no merge to main was performed.
