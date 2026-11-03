#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skia_root=${NATIVE_SKIA_ROOT:-"$repo_dir/../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic"}
library_dir=${NATIVE_GRAPHITE_TEST_LIBRARY_DIR:-"$repo_dir/Build/v/Vox.app/Contents/MacOS"}
output_dir=${NATIVE_GRAPHITE_CONTEXT_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-graphite-context-lifetime"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -I"$skia_root/include/skia" \
    "$repo_dir/tools/native_graphite_context_lifetime_test.cpp" \
    -L"$skia_root/lib" -lskia -framework CoreFoundation -framework CoreGraphics \
    -Wl,-rpath,"$skia_root/lib" -Wl,-rpath,"$library_dir" \
    -o "$output_dir/context_test"
"$output_dir/context_test" "$library_dir/libVoxGraphite.dylib" "$library_dir/libVoxGraphiteDawn.dylib"
