#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
case "$(uname -m)" in
    arm64|aarch64) brew_prefix=/opt/homebrew ;;
    x86_64|amd64) brew_prefix=/usr/local ;;
    *) echo "Unsupported architecture" >&2; exit 1 ;;
esac
# The browser binds the property bridge to Homebrew's pinned icu4c@78 keg
# (libjs/regex_unicode_property_names.c.v) while other code may resolve the
# current Homebrew ICU, which can have a newer major version.
platform_icu="$brew_prefix/opt/icu4c"
pinned_icu="$brew_prefix/opt/icu4c@78"
output_dir=${NATIVE_ICU_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-icu-link-test"}
mkdir -p "$output_dir"
# Match the browser's potentially competing search paths, placing the current
# Homebrew ICU first. Its -licuuc must coexist with the exact pinned library.
cc -std=c11 -O2 -Wall -Wextra -Werror \
    -I"$platform_icu/include" -L"$platform_icu/lib" \
    "$repo_dir/tools/native_icu_link_test.c" -licuuc "$pinned_icu/lib/libicuuc.78.dylib" \
    -o "$output_dir/native_icu_link_test"
"$output_dir/native_icu_link_test"
