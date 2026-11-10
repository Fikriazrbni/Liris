"""Bundle the local redistributable Python distribution and pinned dependencies."""
import shutil, subprocess, sys
from pathlib import Path
root, app = map(Path, sys.argv[1:])
python = (root / '.runtime/shazamio/bin/python').resolve()
source = python.parent.parent
target = app / 'Contents/Resources/Python'
if target.exists(): shutil.rmtree(target)
shutil.copytree(source, target, symlinks=True, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
packages = target / 'lib/python3.12/site-packages'
shutil.copytree(root / '.runtime/shazamio/lib/python3.12/site-packages', packages, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
for name in ['_virtualenv.pth', '_virtualenv.py']:
    (packages / name).unlink(missing_ok=True)
for link in target.rglob('*'):
    if link.is_symlink():
        if not link.resolve().is_relative_to(target.resolve()):
            raise RuntimeError('External runtime symlink: ' + str(link))
# Sign each embedded native executable/library before signing the outer app.
magic = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}
for path in target.rglob('*'):
    if path.is_file() and not path.is_symlink():
        with path.open('rb') as file: header = file.read(4)
        if header in magic:
            subprocess.run(['codesign', '--force', '--sign', '-', str(path)], check=True, capture_output=True)
subprocess.run([str(target/'bin/python3.12'), '-I', '-B', str(app/'Contents/Resources/backend/shazamio_worker.py'), '--check'], check=True)
