#!/bin/sh
# Compares the Skia-free cpuraster module with the original LibWeb Skia calls.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
output_dir=${1:-"$repo_dir/Build/gg-cpu-raster"}
count=${2:-20000}
seed=${3:-20261106}
v_compiler=${V_BIN:-"$HOME/code/v/v"}
platform=$(uname -s)
case "$platform" in
    Darwin)
        upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
        case "$(uname -m)" in
            arm64|aarch64) triplet=arm64-osx-dynamic ;;
            x86_64|amd64) triplet=x64-osx-dynamic ;;
            *) echo 'Unsupported macOS architecture' >&2; exit 1 ;;
        esac
        skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$triplet}"
        oracle_name=skia_cpu_oracle.dylib
        ;;
    Linux)
        skia_root=${CPU_RASTER_SKIA_ROOT:-"$repo_dir/Build/deps/skia"}
        oracle_name=skia_cpu_oracle.so
        ;;
    *) echo 'This check requires macOS or Linux' >&2; exit 1 ;;
esac
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
unset VEXE VFLAGS
python3 - "$repo_dir" "$v_compiler" "$skia_root" "$output_dir/inputs.json" <<'PY'
import hashlib,json,os,platform,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]); compiler=Path(sys.argv[2]); skia=Path(sys.argv[3])
files=[*sorted(root.glob('cpuraster/*.[vh]')),*sorted(root.glob('gfxfont/*.[vh]')),
       *sorted(root.glob('skia/*.cpp')),*sorted(root.glob('skia/*.h')),
       root/'platform/native_state.h',root/'tools/gg_migration/cpu_raster_check.v',
       root/'tools/gg_migration/skia_cpu_oracle.cpp',root/'tools/gg_migration/test_cpu_raster.sh',
       compiler]
if platform.system() == 'Linux':
    files += [skia/'out/Release/libskia.a',skia/'out/Release/libskcms.a',skia/'out/Release/args.gn']
    files += sorted(skia.glob('include/**/*.h'))
    for package, library in [('freetype2','freetype'),('fontconfig','fontconfig')]:
        directory=Path(subprocess.check_output(['pkg-config','--variable=libdir',package],text=True).strip())
        files.append(directory/('lib'+library+'.so'))
else:
    files.append(skia/'lib/libskia.dylib')
    files += sorted(skia.glob('include/skia/**/*.h'))
if platform.system() == 'Darwin' and os.environ.get('CPU_RASTER_FREETYPE') == '1':
    files += list(skia.glob('lib/libfreetype*.dylib'))
font_list=root/'tools/gg_migration/glyph_fonts.txt'
files += [font_list, *sorted(root.glob('cpuraster/testdata/*'))]
font_paths=[os.environ['CPU_RASTER_GLYPH_FONT']] if os.environ.get('CPU_RASTER_GLYPH_FONT') else font_list.read_text().splitlines()
for value in font_paths:
    if not value.strip() or value.startswith('#'): continue
    path=Path(value) if Path(value).is_absolute() else root/value
    if path.is_file(): files.append(path)
files=[p for p in files if p.is_file()]
Path(sys.argv[4]).write_text(json.dumps({str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
PY
if [ "$platform" = Linux ]; then
    # The reference alone links Skia. The V candidate uses cpuraster and
    # system font services; it never links the reference library.
    # pkg-config emits compiler/linker words, not shell source.
    set -- $(pkg-config --cflags --libs freetype2 fontconfig libpng libjpeg libwebp libwebpdemux zlib)
    clang++ -std=c++20 -O2 -fno-rtti -shared -fPIC \
        -I"$skia_root" -DSK_HIDE_PATH_EDIT_METHODS -DSK_R32_SHIFT=16 \
        "$repo_dir/tools/gg_migration/skia_cpu_oracle.cpp" \
        "$skia_root/out/Release/libskia.a" "$skia_root/out/Release/libskcms.a" \
        "$@" -ldl -lpthread \
        -o "$output_dir/$oracle_name"
else
    set --
    if [ "${CPU_RASTER_FREETYPE:-0}" = 1 ]; then set -- -DCPURASTER_FREETYPE_ORACLE; fi
    clang++ -std=c++20 -O2 -fno-rtti -dynamiclib "$@" \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/gg_migration/skia_cpu_oracle.cpp" -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/$oracle_name"
fi
set --
if [ "${CPU_RASTER_TEST_PROD:-0}" = 1 ]; then set -- -prod -gc none; fi
if [ "${CPU_RASTER_FREETYPE:-0}" = 1 ]; then set -- "$@" -d cpuraster_freetype; fi
# Keep the differential baseline on the C backend independently of the
# browser manifest's selected backend. FastC has separate focused checks.
"$v_compiler" -b c -cc clang -memory-limit 10G "$@" -path "$repo_dir|@vlib|@vmodules" \
    -o "$output_dir/cpu_raster_check" "$repo_dir/tools/gg_migration/cpu_raster_check.v"
python3 - "$output_dir/inputs.json" "$output_dir/cpu_raster_check" "$output_dir/$oracle_name" <<'PY'
import hashlib,json,sys
from pathlib import Path
receipt=Path(sys.argv[1]); hashes=json.loads(receipt.read_text())
for value in sys.argv[2:]:
    path=Path(value).resolve(); hashes[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
receipt.write_text(json.dumps(hashes,indent=2)+'\n')
PY
"$output_dir/cpu_raster_check" "$output_dir/$oracle_name" "$count" "$seed"
python3 - "$output_dir/inputs.json" <<'PY'
import hashlib,json,sys
from pathlib import Path
expected=json.loads(Path(sys.argv[1]).read_text())
changed=[p for p,h in expected.items() if not Path(p).is_file() or hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
if changed: raise SystemExit('Inputs changed during cpuraster checks: '+str(changed))
print('cpuraster inputs unchanged')
PY
