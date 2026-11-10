# Three entry points share one redistributable runtime directory.
from pathlib import Path
from PyInstaller.utils.hooks import collect_all, copy_metadata
import PySide6
import os
import sys

# Do not let developer tools on PATH supply unrelated DLLs (e.g. Poppler's
# incompatible icuuc.dll in Codex). Qt uses the Windows ICU API on this target.
os.environ['PATH'] = os.pathsep.join([sys.base_prefix, str(Path(sys.base_prefix) / 'DLLs'),
                                    str(Path(os.environ['SystemRoot']) / 'System32'), os.environ['SystemRoot']])

root = Path(SPECPATH)
repo = root.parent
shazam_data, shazam_bins, shazam_hidden = collect_all('shazamio')
metadata = copy_metadata('shazamio')

def analyze(entry, **kwargs):
    return Analysis([str(root / entry)], pathex=[str(root), str(repo / 'backend')], **kwargs)

gui = analyze('main.py', datas=[(str(repo / 'Extension'), 'Extension')],
              hiddenimports=['pyaudiowpatch', 'scipy.signal', 'numpy'])
host = analyze('host.py', datas=[(str(repo / 'Extension'), 'Extension')],
               excludes=['PySide6', 'numpy', 'scipy', 'shazamio'])
worker = analyze('worker.py', datas=shazam_data + metadata, binaries=shazam_bins,
                 hiddenimports=shazam_hidden, excludes=['PySide6', 'scipy', 'numpy'])

def executable(a, name, console):
    return EXE(PYZ(a.pure), a.scripts, [], exclude_binaries=True, name=name,
               console=console, debug=False, strip=False, upx=False)

app = executable(gui, 'Liris', False)
bridge = executable(host, 'LirisBridge', True)
recognizer = executable(worker, 'LirisWorker', True)
# Python 3.13 ships an older MSVC runtime than Qt 6.12. Loading Python's copy
# first prevents QtCore from resolving newer exports. Redistribute one compatible
# newer runtime at the root, before any of the three entry points loads Python.
qt_root = Path(PySide6.__file__).parent
runtime = [(p.name, str(p), 'BINARY') for p in qt_root.glob('*.dll')
           if p.name.upper().startswith(('VCRUNTIME140', 'MSVCP140'))]
runtime_names = {p[0].lower() for p in runtime}
def without_old_runtime(binaries):
    return [item for item in binaries if item[0].lower() not in runtime_names]
bundle = COLLECT(app, bridge, recognizer, runtime, without_old_runtime(gui.binaries), gui.datas,
                 without_old_runtime(host.binaries), host.datas,
                 without_old_runtime(worker.binaries), worker.datas, strip=False, upx=False, name='Liris-Windows')
