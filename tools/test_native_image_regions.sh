#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then
    echo "usage: $0 REFERENCE_APP_MACOS_DIR CANDIDATE_GRAPHITE_DIR" >&2
    exit 2
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
reference_dir=$(CDPATH= cd -- "$1" && pwd)
graphite_dir=$(CDPATH= cd -- "$2" && pwd)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic ;;
    *) echo "Unsupported macOS architecture" >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
output_dir=${NATIVE_IMAGE_REGION_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-image-region-test"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_graphite_image_region_test.cpp" -o "$output_dir/graphite-image-region-test"
"$output_dir/graphite-image-region-test" "$reference_dir/libVoxGraphite.dylib" "$graphite_dir/libVoxGraphite.dylib"
clang++ -std=c++20 -O2 -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_image_region_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/skia-image-region-test"
VOX_SKIA_REFERENCE_LIBRARY="$reference_dir/libLadybirdVSkiaText.dylib" \
    DYLD_LIBRARY_PATH="$graphite_dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$output_dir/skia-image-region-test"
