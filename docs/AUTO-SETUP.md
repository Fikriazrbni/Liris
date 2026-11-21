# Auto mode on macOS

This guide covers the extension and recognition paths available in 0.4.4 and later.

## YouTube and YouTube Music in Brave

1. Move the downloaded app to the location where you plan to keep it. **Open Extension and Brave** registers the native host at that bundle location. The app handles registration directly. Developers can also use `python3 scripts/install-auto-bridge.py`. Setup registers the Liris host and leaves JavaScript settings, browser preferences and other extensions alone.
2. Open Liris and choose **Connection Guide → Open Extension and Brave**.
3. On `brave://extensions`, turn on **Developer mode**, choose **Load unpacked** and select the `AutoExtension` folder that Liris opened. The extension uses its own installation permissions and works with **Allow JavaScript from Apple Events** switched off.
4. Reload the YouTube or YouTube Music tab, choose **Auto** in Liris, and click **Connect** if disconnected.

The extension can run while Liris is closed. Its native host stores current playback metadata in `~/Library/Application Support/Liris/Bridge`. The extension accepts only the configured YouTube domains. It uses native messaging without a local HTTP server or network port and sends no recordings, cookies, or browsing history. A metadata heartbeat expires after three seconds. Playing tabs take priority. If multiple tabs are playing, Liris keeps the previous source when possible. A YouTube channel name can differ from the recording artist, so some videos require a manual lyric search.

Play/pause targets the player button in the selected tab. Seeking is disabled when the video node disagrees with the progress bar. The older Apple Events route remains available under the YouTube Music source. Selecting Auto does not enable it.

## Discord and other system audio with ShazamIO

The packaged runtime includes ShazamIO 0.9.0 and Python 3.12. This integration works without an App ID, provisioning profile, API key, or Apple Developer account. Choose **Auto**, connect, and select **Enable Audio** in the status panel at the top of the window. Grant **Screen & System Audio Recording** permission when macOS prompts. Audio recognition starts off every session. Connecting or reconnecting leaves it off, and the app discards the old persistent opt-in preference.

Choose **Stop Audio** in the main status panel, Liris menu bar, connection guide, or unlocked overlay. **Disconnect** also stops capture and the worker. The menu bar control remains accessible while the overlay is locked.

Liris holds each 12-second sample in RAM as 44,100 Hz mono PCM16 and passes it to the Python worker over stdin. ShazamIO generates a signature and uses Shazam's online service to identify the recording. Samples can include anything played through the system output, including Discord conversations. Liris does not open the microphone or write WAV files or permanent recordings. When the extension reports active YouTube or YouTube Music playback, Liris cancels the worker and empties the sample buffer. Collection for the audio fallback resumes once the extension path is idle.

The position estimate combines the recognition offset with monotonic time elapsed since the sample started. This accounts for the time spent collecting the sample and waiting for a network response. A silence gate, result expiry, one active worker, timeout, cooldown and cancellation tokens prevent overlapping retries and stale results. Use the source player to pause or seek when using recognition. Live recordings, covers, mixed speech, track changes and altered playback speed can all cause a missed match or uncertain timing.

Since 0.4.3, the Python runtime and ShazamIO dependencies are inside `Liris.app/Contents/Resources/Python`. The app can move before extension setup and runs independently of the source checkout and system Python. For development, `./scripts/setup-shazamio.sh` prepares the local build runtime. Then `./scripts/build-app.sh` copies the redistributable runtime, dependencies and licenses into the bundle and signs the native libraries. Dependency versions are pinned in `backend/requirements.lock`. This bundle targets Apple Silicon.

ShazamIO uses an unofficial API that can change. The browser extension takes priority whenever it can read the position directly from the player.

## What the tests cover

Build, unit and protocol checks can run automatically. Installing the extension requires the **Load unpacked** step in the browser. Live recognition requires macOS capture permission and an identifiable recording. Unit tests, worker imports and sample-format checks alone cannot establish that a particular recording is recognizable.

## Audio diagnostics introduced in 0.4.1

The status indicates whether capture is off, waiting for audio, receiving silence, collecting a sample, recognizing a track, or reporting a missed match or error. Activation errors remain visible until handled. Since 0.4.2, **Disconnect** stops capture and **Connect** leaves it off until the user turns it on.

A short gap in audio holds the track identity for the result's lifetime and pauses its clock during silence. Liris clears the identity once it expires without a new result. This prevents brief silence from discarding the track and cancelling its lyric lookup. The app overwrites `~/Library/Caches/id.local.liris/audio-status.json` with diagnostic metrics such as callback count, level, buffer size, worker state, errors and lyric status. The file contains no audio. Use `--diagnose-audio` to read it and check `updatedAt` before relying on its state.

`--probe-audio` tests local capture for 15 seconds without a worker or network request. `--probe-recognition` tests recognition for up to 35 seconds and sends an audio signature to Shazam. Only run it with consent for the audio being played. The old `--resume-auto-audio` argument was removed in 0.4.2 and cannot activate capture on launch.

If diagnostics show a TCC denial, use the **Screen & System Audio Recording** permissions button in the connection guide, then enable Liris in that category. The ScreenCaptureKit implementation uses a display filter even though it consumes only audio output. Audio Recording permission alone may be insufficient. After replacing an ad hoc signed build, macOS may require a new grant. Quit and reopen Liris after changing the setting. A successful terminal or Codex probe does not establish permissions for the normally launched app.

If permission is still denied after toggling it and restarting, remove the old Liris entry with the minus button, use the plus button to add the exact `dist/Liris.app` being tested, enable it and reopen Liris. This replaces an entry that may refer to an older build's signing identity. Use the same build from the permission grant through the test.

## Audio indicators and privacy in 0.4.2

The status panel shows Off, Starting, Active or Stopping. When capture is active, an orange indicator appears in the main window and overlay, and the menu bar icon becomes a recording circle. If extension playback suppresses recognition, the indicator stays active: capture continues, while Liris cancels the Shazam worker and clears the recognition buffer. **Stop Audio** drops the buffer, cancels the worker or any pending start, and stops the stream. Old replies cannot reactivate a stopped session. The indicator reads Stopping until shutdown completes.

Liris reads system output only. On macOS 15+, it explicitly sets `captureMicrophone` to `false`. It requests no microphone permission, opens no mic input and creates no microphone output stream. Speaking into a Discord mic does not by itself send your voice to Liris. Other participants' voices play through the system output and can be analyzed. Your own voice may also appear there through monitoring, echo or loopback. Mixed speech can cause missed matches, incorrect matches or less accurate positions. Turn off recognition during private conversations. YouTube and YouTube Music can use the extension with audio recognition off.
