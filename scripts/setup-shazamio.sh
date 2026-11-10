#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
export UV_PYTHON_INSTALL_DIR="$project_dir/.runtime/python"
export UV_CACHE_DIR="$project_dir/.build/uv-cache"
uv venv --python 3.12 "$project_dir/.runtime/shazamio"
uv pip install --python "$project_dir/.runtime/shazamio/bin/python" -r "$project_dir/backend/requirements.lock"
"$project_dir/.runtime/shazamio/bin/python" "$project_dir/backend/shazamio_worker.py" --check
