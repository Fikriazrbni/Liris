#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"
swift_bin_dir="$(dirname "$(xcrun --find swiftc)")"
testing_plugin="$swift_bin_dir/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
testing_flags=()
# Some Command Line Tools incremental builds omit automatic Testing macro discovery.
if [[ -f "$testing_plugin" ]]; then
    testing_flags=(-Xswiftc -load-plugin-library -Xswiftc "$testing_plugin")
fi
swift test --disable-sandbox --scratch-path "$project_dir/.build" --cache-path "$project_dir/.build/swift-cache" --config-path "$project_dir/.build/swift-config" --security-path "$project_dir/.build/swift-security" "${testing_flags[@]}"
