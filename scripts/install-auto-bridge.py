#!/usr/bin/env python3
"""Registers only Liris' native host; never changes Brave preferences or JS permissions."""
import json,base64,hashlib
from pathlib import Path
root=Path(__file__).resolve().parent.parent
manifest=json.loads((root/'Extension/manifest.json').read_text())
identifier=''.join(chr(97+int(n,16)) for n in hashlib.sha256(base64.b64decode(manifest['key'])).hexdigest()[:32])
host=root/'dist/Liris.app/Contents/MacOS/LirisBridge'
if not host.exists(): raise SystemExit('Build Liris.app first')
configuration={'name':'id.local.liris.bridge','description':'Liris local playback bridge','path':str(host),'type':'stdio','allowed_origins':['chrome-extension://'+identifier+'/']}
for profile in ['BraveSoftware/Brave-Browser']:
 folder=Path.home()/'Library/Application Support'/profile/'NativeMessagingHosts'
 folder.mkdir(parents=True,exist_ok=True)
 (folder/'id.local.liris.bridge.json').write_text(json.dumps(configuration,indent=2)+'\n')
print('Native host registered. Extension ID: '+identifier)
print('Load unpacked extension from: '+str(root/'Extension'))
