# Liris Windows icon

`liris.ico` contains PNG frames at 16, 20, 24, 32, 40, 48, 64, 128 and 256 pixels.
`liris.png` is the 512-pixel preview. Regenerate using `python generate_icon.py`.

The rounded lime tile and seven waveform bars use the existing geometry in
`scripts/generate-icon.swift`, rendered by `liris/branding.py`. No Mac files change.
The same renderer supplies Qt window, taskbar, sidebar and tray icons. The tray adds
an orange badge while audio is active/stopping, preserving the existing state logic.
Windows process AppUserModelID: `id.local.liris.Windows`.
