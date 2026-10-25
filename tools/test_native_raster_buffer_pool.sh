#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_RASTER_POOL_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-raster-buffer-pool-test"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror -pthread     "$repo_dir/tools/native_raster_buffer_pool_test.cpp" -o "$output_dir/ownership"
"$output_dir/ownership"
clang++ -std=c++20 -O1 -g -fsanitize=address,undefined -pthread     "$repo_dir/tools/native_raster_buffer_pool_test.cpp" -o "$output_dir/ownership-sanitized"
"$output_dir/ownership-sanitized"
