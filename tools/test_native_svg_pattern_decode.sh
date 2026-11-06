#!/bin/sh
set -eu
# Run this compile/test entrypoint through tools/run_memory_bounded.py.
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic ;;
    *) echo "Unsupported macOS architecture" >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-svg-pattern-decode-test"}
graphite_dir=${NATIVE_GRAPHITE_DIR:-"$repo_dir/Build/v/Vox.app/Contents/MacOS"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -fno-rtti -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_svg_pattern_decode_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText \
    -framework Foundation -framework Metal -framework ImageIO \
    -Wl,-rpath,"$skia_root/lib" -Wl,-rpath,"$graphite_dir" \
    -o "$output_dir/native-svg-pattern-decode-test"
python3 "$repo_dir/tools/run_memory_bounded.py" --limit-gib 3 \
    --lock "$output_dir/run.lock" --report "$output_dir/run.json" -- \
    "$output_dir/native-svg-pattern-decode-test"
