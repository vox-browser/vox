#!/bin/sh
# The differential corpus lives in vox-browser/vox-tests, pinned by Vox.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
exec python3 "$repo_dir/tools/raster_tests.py" test_cpu_raster.sh "$@"
