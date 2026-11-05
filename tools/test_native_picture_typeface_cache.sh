#!/bin/sh
set -eu
if [ "$#" -ne 0 ] && [ "$#" -ne 2 ]; then
    echo "usage: $0 [CONTROL_DAWN_LIBRARY CANDIDATE_DAWN_LIBRARY]" >&2
    exit 2
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic ;;
    *) echo "Unsupported macOS architecture" >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-picture-typeface-cache-test"}
mkdir -p "$output_dir"
sanitizer_flags=
if [ "${NATIVE_SKIA_TEST_SANITIZE:-0}" = 1 ]; then
    sanitizer_flags='-fsanitize=address,undefined -fno-omit-frame-pointer'
fi
clang++ -std=c++20 -O2 -Wall -Wextra -Werror $sanitizer_flags \
    -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_picture_typeface_cache_test.cpp" \
    -L"$skia_root/lib" -lskia \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_picture_typeface_cache_test"
if [ "${NATIVE_SKIA_TEST_COMPILE_ONLY:-0}" != 1 ]; then
    "$output_dir/native_picture_typeface_cache_test" "$@"
fi
