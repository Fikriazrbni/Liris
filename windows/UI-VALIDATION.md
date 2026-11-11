# Windows UI revision

## Current simplified revision — 11 November 2026

The listening page now uses a 172 DIP sidebar and no permanent settings column.
Colors, font size, opacity, offset and click-through settings appear only on
**Tampilan**. Decorative slogans and repeated overlay/import/version controls were
removed from the listening page. **Lainnya** contains lyric version selection,
refresh and import; the existing connection/disconnection callbacks share one
Hubungkan/Putuskan button. Connection remains fixed above the scrolling lyric stage.
Default window size is 1100×740; the minimum is 840×600.

Overlay now displays **previous / active / next** timed lyric rows. The active row
retains the larger accent font, adjacent rows use muted 18 px text, and missing
neighbors at song boundaries stay blank. Header, audio status and unlocked Stop
remain available. Default overlay is 800×230, with minimum height adapting to wrapped
lyrics and font size. Click-through and topmost behavior are unchanged.

37 Windows tests passed, including three-row progression/backward seek/boundaries
and settings visibility/connection behavior. Offline render fixtures cover the same
1220×790 and 940×640 matrix at effective DPR 1/1.25/1.5/2. No real audio capture,
recognition request, clock, backend or extension change is part of this revision.
PNG evidence remains under `.test-data/visual/<factor>/`, including `overlay.png`
and `overlay-locked.png`. The earlier layout description below is historical.

Reference: all seven supplied Mac v0.4.3 PNGs were extracted from the user's ZIP
and visually inspected. Mac main viewport is treated as 1220×790 logical points,
not 2440 DIP. No Mac source, build, release or shared backend/extension was changed.

## Changes

- `liris/theme.py`: centralized colors and component styles, keyboard focus,
  hover/pressed/disabled states, Windows High Contrast detection.
- `liris/presentation.py`: 205 DIP sidebar, persistent audio banner, listening/search/
  appearance/Windows connection guide pages, 252 DIP independently scrolling settings,
  106 DIP placeholder record art, lyric delegate, thin sliders and playback timeline.
- `liris/ui.py`: delegates layout creation; overlay 800×180 with song/next-line/status;
  existing callbacks and production state remain authoritative. Centered lyric scroll
  runs only on active-line changes, with optional 180 ms easing respecting Windows
  client-area animation preference. Small windows can scroll the stage while playback,
  header and the audio banner stay fixed.
- `visual_verify.py`: offline fixtures with original lyrics, explicit DEMO badge,
  mocked capture/network entry points, isolated settings folder, native Qt widget PNGs
  and bounds/tab-navigation assertions. This script is not production startup.

Audio engine, clock algorithms, source selection, LRCLIB/cache/version/offset logic,
native messaging and stored data formats have no changes in this UI revision.

## Render evidence

`windows/.test-data/before-1220.png` is the actual old Qt Windows UI in an empty state.
The comparable after image is `.test-data/visual/1/1220-empty.png`; populated original
demo is `.test-data/visual/1/1220-off.png`. Audio-active imagery is simulation only.

The core matrix renders 12 states at **1220×790** and **940×640**: off, active,
starting, stopping, suppressed, uncertain, empty, loading, error, appearance, guide,
search. Both overlay unlocked and locked are also rendered. Primary controls are
asserted within the visible window; long settings and content are scrollable.

Effective device pixel ratios verified: **1.0, 1.25, 1.5, 2.0**. The machine's native
screen DPR is 1.25; QT_SCALE_FACTOR values 0.8, 1, 1.2, 1.6 exercise these effective
scales in separate processes. The Windows display setting was not changed, and
cross-monitor DPI transitions were not tested. Additional Qt factors 1.25/1.5/2 were
rendered too, with actual DPR recorded in each `report.json`.

Visual review caught and corrected overlapping metadata in the compact viewport,
active-line wrap clipping, and an overly bright native slider track. Core render
PNGs and reports are in `.test-data/visual/<factor>/` (local, ignored by Git).
Tab navigation is exercised using Qt key events. Capture and network are explicitly
blocked during fixture generation. No real audio or account information is used.

## Verification and limits

35 existing Windows regression tests pass, including manual audio activation,
startup/reconnect off, stale-result rejection, offset/version persistence, native
topmost/click-through styles and tray Stop. Packaged smoke verifies Python-free PATH,
native host/worker imports, rendered startup/reconnect/overlay, without capture.

Not manually verified in this revision: Windows High Contrast mode, screen reader,
live hover/pressed interactions on every control, multi-monitor DPI transitions,
native file-picker appearance, or real playback/audio synchronization. High Contrast
uses the OS widget palette instead of the main custom stylesheet; decorative artwork
and some secondary overlay text still retain custom colors. No claim of exact Mac
parity or live synchronization is based on these visual fixtures.
