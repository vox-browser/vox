#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir="$repo_dir/Build/scroll-performance/native-tests"
mkdir -p "$test_dir"
clang -O2 -Wall -Wextra -Werror "$@" -I"$repo_dir" -framework CoreGraphics \
    "$repo_dir/tools/native_svg_mask_layer_test.c" -o "$test_dir/svg-mask-layers"
"$test_dir/svg-mask-layers"
