#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$project_dir/dist/Liris.app" ]]; then
    "$project_dir/scripts/build-app.sh"
fi
open "$project_dir/dist/Liris.app" --args "$@"
