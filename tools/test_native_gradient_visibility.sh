#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic ;;
    *) echo "Unsupported macOS architecture" >&2; exit 1 ;;
esac
skia_root="${LADYBIRD_SOURCE_DIR:-$repo_dir/../3rd/ladybird}/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-gradient-visibility"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-function -x objective-c++ \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_gradient_visibility_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_gradient_visibility_test"
"$output_dir/native_gradient_visibility_test"
