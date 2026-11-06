#!/bin/sh
# Compares the Skia-free cpuraster module with the original LibWeb Skia calls.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
output_dir=${1:-"$repo_dir/Build/gg-cpu-raster"}
count=${2:-20000}
v_compiler=${V_BIN:-"$HOME/code/v/v"}
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) triplet=arm64-osx-dynamic ;;
    x86_64|amd64) triplet=x64-osx-dynamic ;;
    *) echo 'This check requires macOS' >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$triplet}"
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
unset VEXE VFLAGS
python3 - "$repo_dir" "$v_compiler" "$skia_root" "$output_dir/inputs.json" <<'PY'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]); compiler=Path(sys.argv[2]); skia=Path(sys.argv[3])
files=[*sorted(root.glob('cpuraster/*.v')),root/'tools/gg_migration/cpu_raster_check.v',root/'tools/gg_migration/skia_cpu_oracle.cpp',root/'tools/gg_migration/test_cpu_raster.sh',compiler,skia/'lib/libskia.dylib']
Path(sys.argv[4]).write_text(json.dumps({str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
PY
clang++ -std=c++20 -O2 -fno-rtti -dynamiclib \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/gg_migration/skia_cpu_oracle.cpp" -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/skia_cpu_oracle.dylib"
set --
if [ "${CPU_RASTER_TEST_PROD:-0}" = 1 ]; then set -- -prod -gc none; fi
"$v_compiler" -cc clang "$@" -path "$repo_dir|@vlib|@vmodules" \
    -o "$output_dir/cpu_raster_check" "$repo_dir/tools/gg_migration/cpu_raster_check.v"
"$output_dir/cpu_raster_check" "$output_dir/skia_cpu_oracle.dylib" "$count"
python3 - "$output_dir/inputs.json" <<'PY'
import hashlib,json,sys
from pathlib import Path
expected=json.loads(Path(sys.argv[1]).read_text())
changed=[p for p,h in expected.items() if not Path(p).is_file() or hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
if changed: raise SystemExit('Inputs changed during cpuraster checks: '+str(changed))
print('cpuraster inputs unchanged')
PY
