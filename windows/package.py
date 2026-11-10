"""Collect license notices and produce a portable ZIP, never a GitHub release."""
import importlib.metadata
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent
bundle = root / 'dist' / 'Liris-Windows'
notices = bundle / 'THIRD-PARTY-LICENSES'
notices.mkdir(parents=True, exist_ok=True)
shutil.copytree(root / 'licenses', notices / 'Qt-license-terms', dirs_exist_ok=True)
inventory = []
for dist in importlib.metadata.distributions():
    inventory.append(f"{dist.metadata['Name']}=={dist.version}  {dist.metadata.get('License-Expression', dist.metadata.get('License', 'See license files'))}")
    for file in dist.files or []:
        # Preserve bundled upstream license texts (Qt, Python wheels, PortAudio,
        # scientific libraries, Rust recognition core and transitive packages).
        if any(word in str(file).lower() for word in ('license', 'copying', 'notice', 'copyright')):
            source = Path(dist.locate_file(file))
            if source.is_file():
                target = notices / dist.metadata['Name'] / str(file).replace('../', '').replace('..\\', '')
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
(notices / 'INVENTORY.txt').write_text('\n'.join(sorted(inventory)), encoding='utf-8')
shutil.copy2(Path(__import__('sys').base_prefix) / 'LICENSE.txt', notices / 'Python-LICENSE.txt')
shutil.copy2(root / 'README.md', bundle / 'README.md')
for name in ('VALIDATION.md', 'ARCHITECTURE.md', 'unregister-bridge.ps1'):
    shutil.copy2(root / name, bundle / name)
shutil.copy2(root / 'requirements.lock', bundle / 'requirements.lock')
shutil.make_archive(str(root / 'dist' / 'Liris-Windows-x64-preview'), 'zip', root_dir=bundle.parent, base_dir=bundle.name)
print('Created windows/dist/Liris-Windows-x64-preview.zip')
