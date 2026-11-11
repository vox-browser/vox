#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic ;;
    *) exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-chromium-contour-deferred"}
graphite_dir=${NATIVE_GRAPHITE_DAWN_DIR:-"$repo_dir/Build/v/Vox.app/Contents/MacOS"}
mkdir -p "$output_dir"
for test_name in native_chromium_contour_deferred_test native_chromium_corner_shape_paint_test native_shared_layer_typeface_test; do
    clang++ -std=c++20 -O2 -fno-rtti -x objective-c++ \
        -I"$skia_root/include/skia" -I"$skia_root/include" \
        "$repo_dir/tools/$test_name.cpp" -L"$skia_root/lib" -lskia \
        -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework IOSurface -framework Metal \
        -Wl,-rpath,"$skia_root/lib" -Wl,-rpath,"$graphite_dir" -o "$output_dir/$test_name"
    python3 "$repo_dir/tools/run_memory_bounded.py" --limit-gib 3 \
        --lock "$output_dir/$test_name.lock" --report "$output_dir/$test_name.json" -- "$output_dir/$test_name"
done
