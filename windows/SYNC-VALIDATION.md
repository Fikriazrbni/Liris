# Live pause / seek / song-change acceptance

This run used the source Windows UI and capture engine with the packaged
`LirisWorker.exe`. It was not an automated simulation, but it also was not a
measurement inside the distributed GUI executable. The production clock/audio/
lyrics/extension code was not modified for this test.

The user operated the source players. System-output capture and signature requests
were already explicitly authorized in this Windows session. Samples stayed in RAM;
only timing, status and recognized metadata were saved. No microphone was opened.

## Results

| Case | Real observation | Assessment |
| --- | --- | --- |
| Discord pause | After the user confirmed pause, the clock held around 113.025 s for successive samples and the active lyric stopped advancing. | Silence-based holding works in the observed interval. Exact pause latency and source position were not available. |
| Long pause / slow refresh | The first recognition arrived at 13.986 s. The track expired at about 49.114 s while another request was running; that request later reported generic ValueError. During a later paused interval, the track expired again after the 35 s TTL. | Identity/lyrics can disappear during slow recognition or a long pause. Not seamless pause handling. |
| Discord track change | User confirmed switching to **This Is How I Disappear — My Chemical Romance**. The previous **Dead!** result was replaced at 110.063 s in run 2, and 40 timed lines were loaded. Confirmation was recorded around 92 s. | Recognition and lyric replacement succeeded, about 18 s after confirmation. This is not latency from the exact source click. |
| Discord seek | User reported that their Discord player cannot rewind. | Not tested; no Discord seek compatibility claim. |
| YouTube Music seek through audio fallback | User played **Drown — Bring Me The Horizon**, then moved playback to the requested 0:30. New signature match offset was 30.983564 s for the sample starting at run time 97.886 s. Result arrived at 110.700 s. | Audio recognition recovered the new time reference after another sample/request. This does not test the extension path. |
| Visible seek correction | At run time 110.129 s, UI was still at 233.724 s / lyric index 53. At 111.127 s, UI jumped back to 44.224 s / index 8, then progressed normally. | Recovery is delayed; old lyrics continue until recognition updates the anchor. Not immediate seek tracking. |

Source-player click timestamps were not captured. The requested seek target and
user confirmations are coarse references, not synchronized clocks. The difference
between 30.98 s at the sample start and roughly 44 s at result arrival includes the
12-second sample and processing/network time. Vocal alignment and subsecond
accuracy were not established.

## Problems exposed

- Silence is inferred from mixed system-output levels, not an explicit Discord
  transport state. Other output sounds can look like resumed playback.
- A 35-second result TTL can expire before a slow refresh completes or while music
  is paused. Lyrics then clear instead of preserving a paused identity.
- Seek/song changes cannot be known immediately from audio metadata. The old clock
  keeps interpolating until a fresh result arrives, and can advance beyond the song
  end because the audio path has no trusted duration.
- Recognition error detail is collapsed to `ValueError` by the capture UI. This
  run does not establish the underlying cause of that particular failure.

These findings are recorded, not described as fixed. No production synchronization
changes were made in this acceptance pass.

## Reproduction and evidence

Developer-only, explicit opt-in; never called from startup, build or CI:

```powershell
cd windows
.venv\Scripts\python.exe live_sync_probe.py --consent-system-output-and-signatures --seconds 180 --report .test-data/live-sync.json
```

An adjacent `.control.json` can set a descriptive `phase` or `stop: true`; it does
not control Discord/YouTube. Phase names ending in `requested` are not evidence that
the action happened. The user supplies confirmations separately.

Local reports (ignored by Git):

- `.test-data/live-sync-discord.json`: initial recognition/pause run, 240 samples.
- `.test-data/live-sync-seek.json`: Discord song-change run, 140 samples; despite
  the filename, no Discord seek occurred.
- `.test-data/live-sync-ytmusic.json`: audio-fallback seek run, 140 samples.

All three runs finished with `stopped: true` and `audioEnabledAfterStop: false`.
No audio files were written by the probe. Existing release ZIPs remain unchanged.

## Old folders

An old **extracted portable package** can be deleted after its Liris process exits
and the new package works. Keep the new folder complete, including `_internal`,
LirisBridge.exe and LirisWorker.exe. If native messaging was registered from the old
folder, run Setup extension from the new package first. Do not confuse old portable
copies with the development repository or its `windows/` source folder.
