#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
case "$(uname -m)" in
    arm64|aarch64) default_triplet=arm64-osx-dynamic; brew_prefix=/opt/homebrew ;;
    x86_64|amd64) default_triplet=x64-osx-dynamic; brew_prefix=/usr/local ;;
    *) echo "Unsupported architecture" >&2; exit 1 ;;
esac
skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
platform_icu="$brew_prefix/opt/icu4c"
output_dir=${NATIVE_ICU_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-icu-link-test"}
mkdir -p "$output_dir"
# Match the browser's potentially competing search paths, placing Homebrew
# first. Its -licuuc must coexist with the exact pinned upstream library.
cc -std=c11 -O2 -Wall -Wextra -Werror \
    -I"$platform_icu/include" -L"$platform_icu/lib" -L"$skia_root/lib" \
    "$repo_dir/tools/native_icu_link_test.c" -licuuc "$skia_root/lib/libicuuc.dylib" \
    -Wl,-rpath,"$skia_root/lib" -o "$output_dir/native_icu_link_test"
"$output_dir/native_icu_link_test"
