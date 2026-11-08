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
if [ -f "$graphite_dir/libVoxGraphiteDawn.dylib" ]; then
    VOX_TEST_PICTURE_LIBRARY="$graphite_dir/libVoxGraphiteDawn.dylib"
else
    VOX_TEST_PICTURE_LIBRARY="$repo_dir/Build/v/Vox.app/Contents/MacOS/libVoxGraphiteDawn.dylib"
fi
export VOX_TEST_PICTURE_LIBRARY
python3 - "$repo_dir" "$VOX_TEST_GRAPHITE_LIBRARY" "$output_dir/inputs.json" "$VOX_TEST_PICTURE_LIBRARY" <<'PIN'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]);backend=Path(sys.argv[2]).resolve()
if not backend.is_file(): raise SystemExit('Requested GPU backend is missing: '+str(backend))
files=[backend,Path(sys.argv[4]).resolve(),root/'native_skia_text_darwin.cpp',root/'native_capture_darwin.m',root/'tools/native_gpu_canvas_test.cpp',root/'tools/native_video_image_resource_test.c',root/'tools/test_native_gpu_canvas.sh',*root.glob('native*.h')]
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
    -MMD -MF "$output_dir/native_gpu_canvas_test.d" \
    -o "$output_dir/native_gpu_canvas_test"
# Build-only is for controllers that run each runtime mode under its own RSS guard.
if [ "${NATIVE_GPU_CANVAS_BUILD_ONLY:-0}" = 1 ]; then exit 0; fi
wrong_backend_status=0
VOX_TEST_GRAPHITE_LIBRARY="$repo_dir/tools/native_gpu_canvas_test.cpp" \
    "$output_dir/native_gpu_canvas_test" --check-backend || wrong_backend_status=$?
if [ "$wrong_backend_status" -ne 1 ]; then
    echo "Backend identity check did not reject a mismatched library" >&2; exit 1
fi
"$output_dir/native_gpu_canvas_test"
"$output_dir/native_gpu_canvas_test" --many-damage-rects
"$output_dir/native_gpu_canvas_test" --line-raster
"$output_dir/native_gpu_canvas_test" --capture-full-frame
"$output_dir/native_gpu_canvas_test" --static-msaa-images
"$output_dir/native_gpu_canvas_test" --cached-gpu-blurs
VOX_GPU_CACHED_BLUR_TEXTURE_DIAGNOSTICS=1 "$output_dir/native_gpu_canvas_test" --cached-gpu-blur-textures > "$output_dir/blur-textures.log" 2>&1
python3 - "$output_dir/blur-textures.log" <<'BLUR_TEXTURES'
from pathlib import Path
import re,sys
assert re.search(r'VOX_GPU_CACHED_BLUR_TEXTURE .*reused=1',Path(sys.argv[1]).read_text()), 'No cached blur texture reuse through the primary bridge'
print('Cached blur texture primary/backend bridge: exported API and texture reuse observed')
BLUR_TEXTURES
VOX_IMAGE_UPLOAD_DIAGNOSTICS=1 "$output_dir/native_gpu_canvas_test" --immutable-msaa-images > "$output_dir/immutable-uploads.log" 2>&1
python3 - "$output_dir/immutable-uploads.log" <<'IDENTITY'
import re,sys
from pathlib import Path
log=Path(sys.argv[1]).read_text()
assert re.search(r'VOX_IMAGE_UPLOAD width=1426 height=1080 .*reused=1 .*immutable=1 identity_hit=1',log), 'No immutable texture reuse through the primary bridge'
print('Immutable primary/backend bridge: exported API and keyed texture reuse observed')
IDENTITY
"$output_dir/native_gpu_canvas_test" --masked-images
VOX_IMAGE_UPLOAD_DIAGNOSTICS=1 "$output_dir/native_gpu_canvas_test" --video-upload-keys > "$output_dir/video-uploads.log" 2>&1
python3 - "$output_dir/video-uploads.log" <<'VIDEO_IDENTITY'
import re,sys
from pathlib import Path
log=Path(sys.argv[1]).read_text()
assert re.search(r'VOX_IMAGE_UPLOAD width=1426 height=1080 .*reused=1 .*immutable=1 identity_hit=1',log), 'No video generation reuse through the primary bridge'
print('Video primary/backend bridge: generation-keyed texture reuse observed')
VIDEO_IDENTITY
for resource_mode in optimized sanitized; do
    resource_flags=-O2
    if [ "$resource_mode" = sanitized ]; then resource_flags='-O1 -g -fsanitize=address,undefined'; fi
    clang -std=c11 $resource_flags "$repo_dir/tools/native_video_image_resource_test.c" -o "$output_dir/video-resources-$resource_mode"
    "$output_dir/video-resources-$resource_mode"
done
"$output_dir/native_gpu_canvas_test" --deferred-video-barriers
"$output_dir/native_gpu_canvas_test" --failed-readback
"$output_dir/native_gpu_canvas_test" --failed-readonly
"$output_dir/native_gpu_canvas_test" --iosurface-readback
"$output_dir/native_gpu_canvas_test" --partial-readback
"$output_dir/native_gpu_canvas_test" --native-grid
"$output_dir/native_gpu_canvas_test" --filter-image
"$output_dir/native_gpu_canvas_test" --layer-pixels
"$output_dir/native_gpu_canvas_test" --text-layer-composite
"$output_dir/native_gpu_canvas_test" --text-mask
"$output_dir/native_gpu_canvas_test" --float-text-mask
"$output_dir/native_gpu_canvas_test" --text-two-clips
"$output_dir/native_gpu_canvas_test" --grazing-text-mask
VOX_DISABLE_CLIPPED_TEXT_MASKS=1 "$output_dir/native_gpu_canvas_test" --grazing-text-mask
"$output_dir/native_gpu_canvas_test" --scale1-root-gradient
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
    "$output_dir/native_gpu_canvas_test" --resident-ring-cpu-seed
VOX_GPU_TILE_DEFER_SCHEDULE_WAIT=1 "$output_dir/native_gpu_canvas_test" --resident-ring
"$output_dir/native_gpu_canvas_test" --resident-ring-legacy-schedule
    "$output_dir/native_gpu_canvas_test" --resident-ring-sparse
    VOX_GPU_CANVAS_PRESENT_VERIFY=1 "$output_dir/native_gpu_canvas_test" --present-tiles
    VOX_GPU_CANVAS_PRESENT_VERIFY=1 "$output_dir/native_gpu_canvas_test" --resident-ring
VOX_GPU_TILE_DEFER_SCHEDULE_WAIT=1 "$output_dir/native_gpu_canvas_test" --resident-ring
"$output_dir/native_gpu_canvas_test" --resident-ring-legacy-schedule
    VOX_GPU_CANVAS_PRESENT_VERIFY=1 "$output_dir/native_gpu_canvas_test" --resident-ring-sparse
fi

python3 - "$output_dir/inputs.json" <<'PIN'
import hashlib,json,sys
from pathlib import Path
inputs=json.loads(Path(sys.argv[1]).read_text())
changed=[p for p,sha in inputs.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=sha]
if changed: raise SystemExit('GPU test inputs changed: '+', '.join(changed))
PIN
