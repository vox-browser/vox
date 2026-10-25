#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir="$repo_dir/Build/scroll-performance/native-tests"
mkdir -p "$test_dir"
clang -O2 -Wall -Wextra -Werror "$@" -I"$repo_dir" \
    "$repo_dir/tools/native_svg_mask_pixels_test.c" -o "$test_dir/svg-mask-pixels"
"$test_dir/svg-mask-pixels"
