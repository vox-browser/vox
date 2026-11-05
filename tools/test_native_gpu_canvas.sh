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
                  'int native_gpu_canvas_begin_rects(',
                  'static int native_try_gpu_css_filter_image(',
                  'int native_gpu_canvas_can_defer_layers(',
                  'static void native_prepare_image_cpu_fallback(',
                  'static int native_try_restore_gpu_video_backdrop(', 'void native_restore_video_backdrop('):
    first = source.index(signature)
    functions.append(source[first:source.index('\n}\n', first) + 2])
Path(sys.argv[2]).write_text('\n'.join(functions) + '\n')
PY
clang++ -std=c++20 -O2 -fno-rtti -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" -I"$output_dir" \
    "$repo_dir/tools/native_gpu_canvas_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework Cocoa -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal -framework QuartzCore -framework IOSurface \
    -Wl,-rpath,"$skia_root/lib" -Wl,-rpath,"$graphite_dir" \
    -Wl,-rpath,"$repo_dir/Build/v/Vox.app/Contents/MacOS" \
    -o "$output_dir/native_gpu_canvas_test"
"$output_dir/native_gpu_canvas_test"
"$output_dir/native_gpu_canvas_test" --static-msaa-images
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
