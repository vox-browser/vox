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
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-skia-partial-capsule-border-test"}
graphite_dir=${NATIVE_GRAPHITE_DAWN_DIR:-"$repo_dir/Build/v/Vox.app/Contents/MacOS"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 ${NATIVE_SKIA_TEST_CXXFLAGS:-} \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_partial_capsule_border_test.mm" \
    -L"$skia_root/lib" -lskia \
    -framework Foundation -framework CoreGraphics -framework ImageIO \
    -Wl,-rpath,"$skia_root/lib" \
    -o "$output_dir/native_skia_partial_capsule_border_test"
if [ "${NATIVE_SKIA_TEST_COMPILE_ONLY:-0}" != 1 ]; then
    "$output_dir/native_skia_partial_capsule_border_test" \
        "$graphite_dir/libVoxGraphiteDawn.dylib" \
        "$repo_dir/Tests/Browser/Brave/expected/engadget-category-borders.png"
fi
