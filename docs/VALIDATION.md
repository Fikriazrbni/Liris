# Local verification on macOS

The initial run took place on November 10, 2026, on an Apple Silicon Mac running macOS 27.2 with Swift 6.4.2 and Command Line Tools. The sections below record results and limitations for the versions tested.

- The release build produced an arm64 `Liris.app` executable.
- The ad hoc signature with the Automation entitlement passed `codesign --verify --deep --strict`.
- All 12 Swift tests passed, covering LRC parsing, timestamps, offsets, backward seeks, track matching, URL encoding, memory and disk caching, rate limits, and non-JSON responses.
- All six Node.js browser adapter contract tests passed. They covered metadata and time snapshots, paused/buffering/ended states, an unavailable player, non-finite values, Unicode and fallback metadata, and ads.
- The bundle contained the JavaScript resource. Detection and control scripts compiled for Chrome, Brave, Safari and Edge. The Spotify and Apple Music scripts also compiled. These checks did not send playback Apple Events.
- A live HTTPS request to LRCLIB for “Evaluasi” by Hindia returned HTTP 200, a duration of 194 seconds and synced lyrics. No lyrics from that response were copied into project files.
- Native SwiftUI renders of the initial screen, lyric demo and overlay were visually checked. The corresponding views are illustrated in `welcome.png`, `preview.png` and `overlay.png`.
- Shell scripts passed `bash -n`, and Info.plist and the entitlements passed `plutil -lint`.

## Manual checks outstanding after the initial run

Synchronization on a real YouTube Music tab still needed a listening test. For the direct Apple Events integration, enable **Allow JavaScript from Apple Events** in Brave, grant Automation permission to Liris, and click **Connect**. Check track changes, pause/resume, seeks, ads, the overlay and timing adjustments against the music. Script compilation and fixture coverage do not establish that the live YouTube Music page still has the same structure.

Intel Macs, other macOS versions, Developer ID distribution and notarization, and browsers beyond the four listed above were outside this run.

## Sync fixes in 0.1.1

A read-only inspection of a live Brave YouTube Music tab found “I Don't Love You” by My Chemical Romance paused at 232.676 seconds. The player showed a total duration of 239 seconds. With the position unchanged, `video.duration` varied between 298.551, 328.505 and 358.459 seconds, while `#progress-bar[aria-valuemax]` stayed at 239. The adapter started taking duration from the progress bar first, the visible time label second, and media duration as a fallback. After the fix, the same tab reported a position of 232.676 seconds and a duration of 239 seconds.

Local LRCLIB record 563657 reported a 239-second duration but had nonempty lyric timestamps through 255.23 seconds. The single version, record 33303505, had identical timing. With the user's consent, an online search found eight other candidates matching title, artist and duration whose timestamps were within the track. Record 7473665, for example, had a duration of 239 seconds and nonempty timestamps from 26.22 to 224.42 seconds. These measurements verified time bounds. Auditory alignment of individual words remained untested.

The client began checking both exact API results and cached records. If a nonempty lyric timestamp is more than three seconds past the end, it skips that result and searches for a valid candidate. An empty end marker does not disqualify a record. A newly available duration triggers rematching. Playback controls also use the snapshot identity when music plays from the YouTube Music home page without a `v` parameter.

All 14 Swift and nine JavaScript tests passed, including regressions for increasing buffered duration and rejecting cached or exact matches whose timing extends past the end of the song. Listening after clicking **Connect** remained a user check.

## Sync fixes in 0.1.2

For “21 Guns” by Green Day, a local read showed the progress bar at 29 seconds, duration 322 seconds, and MediaSession paused. The video element still reported 172.187 seconds and a duration of 321 seconds. Cached lyric record 3653924 had a duration of 321 seconds and its timestamps were within track bounds. The end-time check added in 0.1.1 could not detect this disagreement between clocks.

The adapter switched to the progress bar when the clocks disagreed and used MediaSession for play/pause. It kept higher-resolution media time when the two readings were within 1.25 seconds. The new PlaybackClock interpolated whole-second readings, kept the same anchor for repeated values, bounded progress during a stall, and reset its anchor on seeks, pauses and source changes. Seeking through a conflicting media node was disabled. The user could still seek in the browser, and play/pause targeted the YouTube Music player button.

Synthetic regressions reproduced the 29 versus 172.187-second observation and covered MediaSession disagreeing with the media node, a zero position, visible time label fallback, repeated whole seconds, buffering, backward seeks, pause/resume, source changes and playback rate. All 19 Swift and 14 JavaScript tests passed. The 0.1.2 release bundle built and passed local signature checks. Scripts compiled for four browsers, Spotify and Apple Music. Diagnostics from the final bundle on the live tab returned `position=29`, `positionSource=progress`, `mediaPosition=172.187185`, `progressPosition=29`, `duration=322` and `playing=false`, consistent with the player UI. Liris was reopened for the user to listen. This investigation sent no “21 Guns” metadata to external services.

## Automatic checks in 0.2.0

After work resumed, all 39 Swift tests across five suites and 14 JavaScript tests passed (53 total). New coverage included clock progression across samples, two clocks stalling and recovering, a slider disagreeing with two other clocks, invalid time input, uncertain timing across versions, incorrect metadata or version rejection, offline assessment cache, restoring a version choice in a new instance, and forcing a refresh with changed timing under the same record ID.

The 0.2.0 release built successfully. Native rendering of the uncertain-sync status panel was checked with original demo data, including the alternative-version menu and recheck button. See `auto-sync-uncertain.png`. This UI simulation measured no vocal alignment. Automatic selection used metadata, timestamp structure and candidate comparisons without analyzing audio.

UserDefaults retained nonzero offsets by track signature. Structurally valid lyric choices and comparison archives were stored locally. Reading an archive rechecked its metadata, and newer results superseded older ones with the same ID. Online checks used the app's usual LRCLIB API without sending audio or account credentials.

The final bundle passed `codesign --verify --deep --strict`, resource checks and script compilation. A 12-sample local diagnostic on a live Brave tab found media time at 4,074.355 seconds for a track lasting 187 seconds. The monitor consistently rejected that value and selected the 109-second progress reading with health `recovered`. The player was paused throughout. The diagnostic sent no track metadata to external services. Liris 0.2.0 was reopened and the ZIP archive updated.

## Combined Auto mode in 0.3.0

The app and native LirisBridge helper built and passed deep/strict code signature checks. All 41 Swift tests, 14 existing adapter regressions and three extension content-script tests passed (58 total). The native host smoke test covered little-endian frame lengths, local timestamp insertion, path traversal rejection and EOF, writing only to a temporary directory.

The native host was installed for the Brave profile with extension ID `lbogacejhoidbiplndajhinepmobfphh` on its allowlist. The **Allow JavaScript from Apple Events** setting stayed unchanged. The extension folder and Brave Extensions page opened for the user to select **Load unpacked**. End-to-end browser-to-app acceptance still required the loaded extension to produce a real heartbeat.

The ScreenCaptureKit and ShazamKit engine compiled, but the local build set `LirisShazamEnabled=false`. No audio capture or Discord matching ran. The Discord path still required ShazamKit App ID configuration, provisioning, signing, and live permission and recognition tests. The guide documented this limitation, the button was disabled, and Auto did not report a Discord connection.

## ShazamIO in 0.4.0

ShazamIO 0.9.0 and a local Python 3.12 runtime replaced ShazamKit, removing the Apple Developer account requirement for this backend. Dependencies were installed and pinned in `backend/requirements.lock`. The worker accepted 44,100 Hz mono PCM16 WAV over stdin without an audio file. Capture stayed off at launch.

All 41 Swift, 17 JavaScript and five Python worker tests passed (63 total). The Python tests covered sample format and duration, no match, offsets relative to the sample, and rejection of negative or non-finite offsets. A network smoke test ran the real ShazamIO worker on a synthetic 12-second tone and returned `matched=false` with exit status 0. It used no Mac output, microphone input or Discord conversation.

Capture used ScreenCaptureKit, mono PCM conversion, a silence gate and 12-second windows. The host allowed one active worker, set a 23-second host timeout and 18-second request timeout, applied a cooldown after failures, cancelled on stop or suppression, and expired old results. Extension playback suppressed the worker and cleared the buffer. The position estimate added the recognition offset to monotonic time elapsed since the sample started.

On the recognition path, duration from lyrics was available only for display and never treated as a player measurement. The recognition clock was marked limited or estimated. At this version the runtime was under `.runtime` in the checkout and the app configuration referenced it by absolute path. The bundle could not yet run on another Mac without that runtime. Testing a real song and macOS capture permissions still required the user to activate recognition from the **Connection Guide**.

## Discord and audio diagnostics in 0.4.1

With the user's permission, a local capture test received audio callbacks and enough mono PCM for a 12-second window. Live recognition identified “Negoro Angin” by Denny Caknan, and the user confirmed the track. An AppModel and LRCLIB test loaded record 31596625 with 48 timed lines, a 312-second metadata duration and a last nonempty timestamp at 297.72 seconds. The diagnostic verified capture, recognition and lyric loading. Listening in the normally launched app was still needed to assess vocal alignment.

In the normally launched app, macOS denied capture with “The user declined TCCs for application, window, display capture.” There were zero callbacks and zero worker attempts. CLI diagnostic permissions differed from those of the launched app. The error was converted into actionable permission guidance, with a button opening **Screen & System Audio Recording**. ScreenCaptureKit used a display filter with audio output only. An audio-only permission grant could still prevent the display enumeration or capture required by that implementation.

The user authorized continuous recognition for the test and re-granted permission after the final build. Both permission categories showed as enabled in System Settings. After replacing the entry and reopening the app, ScreenCaptureKit logged TCC Allow and started the stream. Diagnostics recorded `running=true`, 939 callbacks and 828,183 PCM frames. The level was zero (silence), so recognition in the normal session still needed music. The diagnostic file briefly held old values while macOS closed the app to apply permissions. Check `updatedAt` when interpreting an error.

When the user resumed music, the app launched through Launch Services received nonzero audio levels, ran the worker and reported `outcome=matched` for “Negoro Angin” by Denny Caknan. Final diagnostics showed `running=true`, `callbacks=4808`, `convertedFrames=4240641`, `attempts=3`, `pending=false`, `lyricLines=48`, an empty `lyricsError`, and a UI status identifying the Auto system-audio route through ShazamIO. This verified capture through recognition and lyric loading in the normally launched app. Vocal timing remained an auditory user check, as recognition returns an estimated position. Continuous testing was left active with the user's consent until **Stop Audio** or **Disconnect**.

The final 0.4.1 bundle passed deep/strict code signing and plist linting. The ZIP was updated before permission was granted again so the binary and signing identity stayed stable throughout permission testing.

## Manual audio controls in 0.4.2

Migration removed the `autoAudioEnabled` preference, and Connect no longer read it. The startup flag `--resume-auto-audio` was removed. Capture required an active Auto connection and an explicit **Enable Audio** action. **Stop Audio** was available in the global status panel, connection guide, menu bar, and unlocked overlay. The locked overlay still showed the indicator. It tracked off, starting, active and stopping, including capture that stayed active while extension playback suppressed the worker. Stop cancelled pending activation, discarded buffers and results, and stopped the worker and stream. Callbacks from an old stream could not stop a new session. On macOS 15+, the app explicitly set `captureMicrophone=false`.

All 41 LirisCore and four AppModel tests passed (45 Swift tests). AppModel tests used fake audio and polling drivers. A stale opt-in, including one written after initialization, could not start capture on connect or reconnect. Manual activation started once even on a double click. Stopping while permission was pending prevented a later start from activating capture. The indicator reflected suppression and unexpected stops. These tests performed no real capture, Shazam requests or lyric lookups.

The 0.4.2 release built after running dsymutil outside the sandbox. Deep/strict signature checks and plist linting passed. Native previews of active, suppressed, off and overlay states were inspected using silent demo data. The settings panel on the right could scroll to keep the banner and controls accessible.

In the normally launched UI, audio recognition showed as off at startup. **Connect → Disconnect → Connect** kept it off and displayed **Enable Audio**. Capture stayed off throughout this test. The app was left connected to Auto with audio off for the user to enable manually. The ZIP at `dist/Liris-macOS-arm64.zip` was updated to 0.4.2.

## Standalone bundle in 0.4.3

The redistributable Python runtime, ShazamIO site-packages and dependency licenses were bundled in `Contents/Resources/Python`. The interpreter no longer depended on an absolute checkout path. Embedded Mach-O libraries and executables were signed before the outer app. The worker ran Python in isolated mode and disabled bytecode writes so imports left the signed bundle intact. A button in the app registered the Brave native host using the installed bundle location.

All 45 Swift tests passed. After moving the bundle to `/private/tmp/liris-release-check`, verification covered isolated Python, imports of `shazamio`, `shazamio_core`, `aiohttp` and `pydantic_core`, the worker's `--check`, resource loading, script compilation and deep/strict signature checks. The release tests performed no audio capture or recognition requests. There was no installed Developer ID identity (`security find-identity` reported zero valid identities). This arm64-only distribution used ad hoc signing without notarization. The GitHub release was marked as a prerelease and the repository was private at that point.

## Public Homebrew tap

At the user's request, Liris and Fikriazrbni/homebrew-tap became public. Cask 0.4.3 pointed to the arm64 release ZIP with SHA-256 `8c4befef3d0a2c5474755a0507253a5088263b0eb9187d250d502e59175c6cc6`. The test command `brew install --cask --appdir=/private/tmp/liris-brew-install fikriazrbni/tap/liris` downloaded, verified and installed the app without a build. The test installation was removed after verification. The cask documented its ad hoc prerelease status, lack of notarization and manual audio recognition.

Both repositories listed Fikriazrbni in CODEOWNERS. At the time of verification, `main` required one review and a code owner review, dismissal of stale approvals, and resolution of review conversations. Force pushes and branch deletion were blocked. Administrators were exempt from the review requirement so the sole owner could maintain the project. The collaborators API listed only Fikriazrbni with write/admin rights on both repositories. Public visibility granted read access.
