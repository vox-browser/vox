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
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-skia-clip-test"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_clip_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_skia_clip_test"
"$output_dir/native_skia_clip_test"
clang++ -std=c++20 -O2 -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_composite_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_skia_composite_test"
"$output_dir/native_skia_composite_test"
clang++ -std=c++20 -O2 -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_shadow_layer_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_skia_shadow_layer_test"
"$output_dir/native_skia_shadow_layer_test"
clang++ -std=c++20 -O2 -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_glyph_cache_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_skia_glyph_cache_test"
"$output_dir/native_skia_glyph_cache_test"
graphite_dir=${NATIVE_SKIA_GRAPHITE_DIR:-"$repo_dir/Build/v/Vox.app/Contents/MacOS"}
if [ -f "$graphite_dir/libVoxGraphite.dylib" ]; then
    clang++ -std=c++20 -O2 -x objective-c++ \
        -I"$skia_root/include/skia" -I"$skia_root/include" \
        "$repo_dir/tools/native_skia_image_root_rows_test.cpp" \
        -L"$skia_root/lib" -lskia \
        -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
        -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_skia_image_root_rows_test"
    DYLD_LIBRARY_PATH="$graphite_dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$output_dir/native_skia_image_root_rows_test"
    clang++ -std=c++20 -O2 -x objective-c++ \
        -I"$skia_root/include/skia" -I"$skia_root/include" \
        "$repo_dir/tools/native_skia_shape_backdrop_test.cpp" \
        -L"$skia_root/lib" -lskia \
        -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
        -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_skia_shape_backdrop_test"
    DYLD_LIBRARY_PATH="$graphite_dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$output_dir/native_skia_shape_backdrop_test"
    clang++ -std=c++20 -O2 -x objective-c++ \
        -I"$skia_root/include/skia" -I"$skia_root/include" \
        "$repo_dir/tools/native_skia_image_tiles_test.cpp" \
        -L"$skia_root/lib" -lskia \
        -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
        -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_skia_image_tiles_test"
    DYLD_LIBRARY_PATH="$graphite_dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$output_dir/native_skia_image_tiles_test"
fi
