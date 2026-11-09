#!/bin/sh
# Match V's native-object C++ dialect and rebuild both bridges from source.
# Run through tools/run_memory_bounded.py; no cached repository .o is linked.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic ;;
    *) echo 'Unsupported macOS architecture' >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
output_dir=$(mktemp -d "$repo_dir/Build/skia-cpp17.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT HUP INT TERM
clang++ -std=c++17 -Werror=c++20-extensions -O2 -fno-rtti \
    -I"$repo_dir" -I"$skia_root/include/skia" -I"$skia_root/include" \
    "$repo_dir/tools/native_skia_cpp17_test.cpp" \
    -L"$skia_root/lib" -lskia -Wl,-rpath,"$skia_root/lib" \
    -framework CoreFoundation -framework CoreGraphics -framework CoreText \
    -o "$output_dir/native_skia_cpp17_test"
"$output_dir/native_skia_cpp17_test"
