#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_SKIA_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-rgba-alpha-bounds"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 "$repo_dir/tools/native_rgba_alpha_bounds_test.cpp" \
    -o "$output_dir/native_rgba_alpha_bounds_test"
"$output_dir/native_rgba_alpha_bounds_test"
clang++ -std=c++20 -O2 -fsanitize=address,undefined -fno-omit-frame-pointer \
    "$repo_dir/tools/native_rgba_alpha_bounds_test.cpp" \
    -o "$output_dir/native_rgba_alpha_bounds_sanitized_test"
"$output_dir/native_rgba_alpha_bounds_sanitized_test"
