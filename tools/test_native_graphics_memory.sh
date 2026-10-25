#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) triplet=arm64-osx-dynamic ;;
    x86_64|amd64) triplet=x64-osx-dynamic ;;
    *) echo "Unsupported macOS architecture" >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$triplet}"
output_dir=${NATIVE_GRAPHICS_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-graphics-memory-test"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror -x objective-c++ \
    "$repo_dir/tools/native_frame_metal_queue_test.mm" \
    -framework Foundation -framework Metal \
    -o "$output_dir/native_frame_metal_queue_test"
"$output_dir/native_frame_metal_queue_test"
python3 "$repo_dir/tools/build_mac_graphite.py" --skia-root "$skia_root" \
    --output "$output_dir/libVoxGraphite.dylib"
clang++ -std=c++20 -O2 -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_graphics_memory_test.mm" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
    -Wl,-rpath,"$skia_root/lib" -Wl,-rpath,"$output_dir" \
    -o "$output_dir/native_graphics_memory_test"
"$output_dir/native_graphics_memory_test" "$output_dir/libVoxGraphite.dylib"
python3 - "$output_dir/libVoxGraphite.dylib" <<'PY'
import subprocess, sys
symbols = {line.split()[-1] for line in subprocess.check_output(['nm', '-gU', sys.argv[1]], text=True).splitlines() if line.strip()}
expected = {'_vox_graphite_draw_shadow_pixels', '_vox_graphite_draw_image_pixels',
    '_vox_graphite_draw_shape_pixels', '_vox_graphite_draw_path_pixels',
    '_vox_graphite_draw_shape_region_pixels', '_vox_graphite_draw_path_region_pixels',
    '_vox_graphite_draw_rounded_parts_pixels',
    '_vox_graphite_draw_image_tiles', '_vox_graphite_draw_path_batch_pixels',
    '_vox_graphite_draw_svg_image_pixels', '_vox_graphite_convert_icc_rgba',
    '_vox_graphite_release_unused_graphics_memory', '_vox_graphite_release_idle_graphics_memory',
    '_vox_graphite_finish_frame'}
assert symbols == expected, (symbols, expected)
print(f'Graphite exports exactly {len(expected)} plain C bridge functions.')
PY
