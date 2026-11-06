#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic ;;
    *) echo "Unsupported macOS architecture" >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-gpu-canvas-test"}
# A libVoxGraphite.dylib exporting the vox_graphite_canvas_* entry points.
graphite_dir=${NATIVE_GRAPHITE_DIR:-"$repo_dir/Build/v/Vox.app/Contents/MacOS"}
mkdir -p "$output_dir"
# An explicit backend must never silently fall back to the installed bundle.
VOX_TEST_GRAPHITE_LIBRARY=$(CDPATH= cd -- "$graphite_dir" && pwd -P)/libVoxGraphite.dylib
export VOX_TEST_GRAPHITE_LIBRARY
python3 - "$repo_dir" "$VOX_TEST_GRAPHITE_LIBRARY" "$output_dir/inputs.json" <<'PIN'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]);backend=Path(sys.argv[2]).resolve()
if not backend.is_file(): raise SystemExit('Requested GPU backend is missing: '+str(backend))
files=[backend,root/'native_skia_text_darwin.cpp',root/'tools/native_gpu_canvas_test.cpp',root/'tools/test_native_gpu_canvas.sh',*root.glob('native*.h')]
Path(sys.argv[3]).write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
PIN
python3 - "$repo_dir/native_capture_darwin.m" "$output_dir/native_video_backdrop_entry_points.inc" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
functions = []
for signature in ('static void native_begin_tracked_transparency_layer(',
                  'static void native_end_tracked_transparency_layer(',
                  'static CGBlendMode native_compositing_operator('):
    first = source.index(signature)
    functions.append(source[first:source.index('\n}\n', first) + 2])
functions.append(source[source.index('// A Chromium-profile opacity group'):
                        source.index('static CGColorRef native_srgb_color(')])
for signature in ('void native_capture_video_backdrop(', 'int native_gpu_canvas_begin(',
                  'int native_gpu_canvas_begin_rects(', 'int native_gpu_canvas_can_present(',
                  'void native_gpu_canvas_end(',
                  'static int native_try_gpu_css_filter_image(',
                  'int native_gpu_canvas_can_defer_layers(',
                  'static void native_prepare_image_cpu_fallback(',
                  'static int native_try_restore_gpu_video_backdrop(', 'void native_restore_video_backdrop('):
    first = source.index(signature)
    functions.append(source[first:source.index('\n}\n', first) + 2])
Path(sys.argv[2]).write_text('\n'.join(functions) + '\n')
PY
compile_flags=-O2
if [ "${NATIVE_GPU_CANVAS_SANITIZERS:-0}" = 1 ]; then compile_flags='-O1 -g -fsanitize=address,undefined'; fi
clang++ -std=c++20 $compile_flags -fno-rtti -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" -I"$output_dir" \
    "$repo_dir/tools/native_gpu_canvas_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework Cocoa -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal -framework QuartzCore -framework IOSurface \
    -Wl,-rpath,"$skia_root/lib" -Wl,-rpath,"$graphite_dir" \
    -Wl,-rpath,"$repo_dir/Build/v/Vox.app/Contents/MacOS" \
    -o "$output_dir/native_gpu_canvas_test"
wrong_backend_status=0
VOX_TEST_GRAPHITE_LIBRARY="$repo_dir/tools/native_gpu_canvas_test.cpp" \
    "$output_dir/native_gpu_canvas_test" --check-backend || wrong_backend_status=$?
if [ "$wrong_backend_status" -ne 1 ]; then
    echo "Backend identity check did not reject a mismatched library" >&2; exit 1
fi
"$output_dir/native_gpu_canvas_test"
"$output_dir/native_gpu_canvas_test" --static-msaa-images
"$output_dir/native_gpu_canvas_test" --masked-images
"$output_dir/native_gpu_canvas_test" --deferred-video-barriers
"$output_dir/native_gpu_canvas_test" --failed-readback
"$output_dir/native_gpu_canvas_test" --failed-readonly
"$output_dir/native_gpu_canvas_test" --iosurface-readback
"$output_dir/native_gpu_canvas_test" --partial-readback
"$output_dir/native_gpu_canvas_test" --native-grid
"$output_dir/native_gpu_canvas_test" --filter-image
"$output_dir/native_gpu_canvas_test" --layer-pixels
"$output_dir/native_gpu_canvas_test" --text-layer-composite
VOX_GPU_CANVAS_DISABLE_DIRECT_LAYER_SHAPES=1 "$output_dir/native_gpu_canvas_test" --overlay-batch
VOX_GPU_CANVAS_DIRECT_NONAA_SHAPES=1 VOX_GPU_CANVAS_DISABLE_DIRECT_LAYER_SHAPES=1 "$output_dir/native_gpu_canvas_test" --overlay-batch
"$output_dir/native_gpu_canvas_test" --overlay-batch
VOX_GPU_CANVAS_VERIFY=2 "$output_dir/native_gpu_canvas_test" --video-backdrop-verify

if [ "${NATIVE_GPU_CANVAS_PRESENT_TEST:-0}" = 1 ]; then
    "$output_dir/native_gpu_canvas_test" --nested-gpu-layers
    "$output_dir/native_gpu_canvas_test" --nested-pop-failure
    "$output_dir/native_gpu_canvas_test" --nested-unclosed
    "$output_dir/native_gpu_canvas_test" --present-tiles
    "$output_dir/native_gpu_canvas_test" --resident-ring
    VOX_GPU_CANVAS_PRESENT_VERIFY=1 "$output_dir/native_gpu_canvas_test" --present-tiles
    VOX_GPU_CANVAS_PRESENT_VERIFY=1 "$output_dir/native_gpu_canvas_test" --resident-ring
fi

python3 - "$output_dir/inputs.json" <<'PIN'
import hashlib,json,sys
from pathlib import Path
inputs=json.loads(Path(sys.argv[1]).read_text())
changed=[p for p,sha in inputs.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=sha]
if changed: raise SystemExit('GPU test inputs changed: '+', '.join(changed))
PIN
