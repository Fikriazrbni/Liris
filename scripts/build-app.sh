#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
    echo "Usage: ./scripts/build-app.sh [release|debug]" >&2
    exit 1
fi
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"
mkdir -p "$project_dir/.build/swift-cache" "$project_dir/.build/swift-config" "$project_dir/.build/swift-security"
swift_args=(--disable-sandbox --scratch-path "$project_dir/.build" --cache-path "$project_dir/.build/swift-cache" --config-path "$project_dir/.build/swift-config" --security-path "$project_dir/.build/swift-security")
swift build "${swift_args[@]}" -c "$configuration"
binary_dir="$(swift build "${swift_args[@]}" -c "$configuration" --show-bin-path)"
app_dir="$project_dir/dist/Liris.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/LirisBridge" "$app_dir/Contents/MacOS/LirisBridge"
cp "$binary_dir/Liris" "$app_dir/Contents/MacOS/Liris"
mkdir -p "$app_dir/Contents/Resources/AutoExtension"
cp "$project_dir/Extension/"* "$app_dir/Contents/Resources/AutoExtension/"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
if [[ -d "$app_dir/Contents/Resources/Liris_LirisApp.bundle" ]]; then
    rm -rf "$app_dir/Contents/Resources/Liris_LirisApp.bundle"
fi
cp -R "$binary_dir/Liris_LirisApp.bundle" "$app_dir/Contents/Resources/"
swift "$project_dir/scripts/generate-icon.swift" "$project_dir/.build/Liris.iconset"
cp "$project_dir/.build/Liris.icns" "$app_dir/Contents/Resources/LirisDock.icns"
if [[ ! -x "$project_dir/.runtime/shazamio/bin/python" ]]; then
    echo "Run ./scripts/setup-shazamio.sh before building the audio-enabled app." >&2
    exit 1
fi
mkdir -p "$app_dir/Contents/Resources/backend"
cp "$project_dir/backend/shazamio_worker.py" "$app_dir/Contents/Resources/backend/"
python3 - "$project_dir" "$app_dir" <<'PYCONFIG'
import plistlib,sys
from pathlib import Path
root,app=map(Path,sys.argv[1:])
with (app/'Contents/Resources/ShazamIO.plist').open('wb') as file:
    plistlib.dump({'PythonPath':str(root/'.runtime/shazamio/bin/python')},file)
PYCONFIG
"$project_dir/.runtime/shazamio/bin/python" "$project_dir/backend/shazamio_worker.py" --check
codesign --force --sign - "$app_dir/Contents/MacOS/LirisBridge"
codesign --force --sign - --options runtime --entitlements "$project_dir/Resources/Liris.entitlements" "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "Built: $app_dir"
