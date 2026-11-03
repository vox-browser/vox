#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_PICTURE_CACHE_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-picture-raster-cache-test"}
dependency_root="$repo_dir/Build/deps/skia-brave-dawn"
source_dir="$dependency_root/source"
dawn_build="$dependency_root/dawn-build"
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 "$repo_dir/tools/native_picture_raster_cache_test.cpp" \
    -o "$output_dir/cache_test"
"$output_dir/cache_test"
# The production Dawn build supplies this pinned source and its static libraries.
clang++ -std=c++20 -O2 -DSK_RELEASE -fno-rtti -mmacosx-version-min=14.0 \
    -DSK_GRAPHITE -DSK_DAWN -DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER \
    -I"$repo_dir" -I"$source_dir" -I"$source_dir/third_party/externals/dawn/include" \
    -I"$dawn_build/gen/include" "$repo_dir/tools/native_picture_raster_replay_test.mm" \
    -L"$source_dir/out/Release" -L"$dawn_build/src/dawn/native" \
    -lskia -lskcms -lwebgpu_dawn \
    -framework CoreText -framework Metal -framework CoreGraphics -framework Foundation \
    -framework ImageIO -framework IOSurface -framework IOKit -framework QuartzCore -framework Cocoa \
    -o "$output_dir/replay_test"
"$output_dir/replay_test"
