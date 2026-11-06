#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
output_dir=${1:-"$repo_dir/Build/gg-clipped-text"}
count=${2:-2000}
v_compiler=${V_BIN:-"$HOME/code/v-gg/v"}
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
printf 'fn main() { println(@VEXEROOT) }\n' > "$output_dir/vroot_probe.v"
v_library_root=$("$v_compiler" -memory-limit 10G run "$output_dir/vroot_probe.v")
python3 - "$repo_dir" "$v_compiler" "$skia_root" "$output_dir/inputs.json" "$v_library_root" <<'PY'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]); compiler=Path(sys.argv[2]); skia=Path(sys.argv[3])
files=[root/'native_gg_text.h',root/'native_glyph_bitmap_surface.h',root/'native_parallel_pixels.h',root/'native_parallel_raster.h',root/'tools/gg_migration/clipped_text_check.v',root/'tools/gg_migration/clipped_text_oracle.mm',root/'tools/gg_migration/test_clipped_text.sh',*root.glob('ggtext/*.v'),*root.glob('platform/*.v'),compiler,skia/'lib/libskia.dylib']
vroot=Path(sys.argv[5])
for directory in [vroot/'vlib/gg/canvas',vroot/'vlib/sokol',vroot/'thirdparty/sokol']:
 files.extend(p for p in directory.rglob('*') if p.is_file() and p.suffix in ['.v','.h','.metal'])
files.extend(Path(p) for p in ['/System/Library/Fonts/Supplemental/Arial.ttf','/System/Library/Fonts/Supplemental/Georgia.ttf','/System/Library/Fonts/Geneva.ttf'])
Path(sys.argv[4]).write_text(json.dumps({str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
PY
clang++ -std=c++20 -O2 -fno-rtti -ffp-contract=off -dynamiclib -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/gg_migration/clipped_text_oracle.mm" -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/clipped_text_oracle.dylib"
set --
if [ "${GG_TEXT_TEST_PROD:-0}" = 1 ]; then set -- -prod -gc none; fi
"$v_compiler" -memory-limit 10G -cc clang -enable-globals -d vox_gg_canvas "$@" \
    -path "$repo_dir|@vlib|@vmodules" -o "$output_dir/clipped_text_check" \
    "$repo_dir/tools/gg_migration/clipped_text_check.v"
"$output_dir/clipped_text_check" "$output_dir/clipped_text_oracle.dylib" "$count"
python3 - "$output_dir/inputs.json" <<'PY'
import hashlib,json,sys
from pathlib import Path
expected=json.loads(Path(sys.argv[1]).read_text())
changed=[p for p,h in expected.items() if not Path(p).is_file() or hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
if changed: raise SystemExit('Inputs changed during clipped text checks: '+str(changed))
print('Clipped text inputs unchanged')
PY
