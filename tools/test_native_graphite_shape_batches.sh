#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then
    echo "usage: $0 CONTROL_GRAPHITE_LIBRARY CANDIDATE_GRAPHITE_LIBRARY" >&2
    exit 2
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_GRAPHITE_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-graphite-shape-batch-test"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_chromium_raster_batch_test.cpp" -o "$output_dir/raster_batch_test"
"$output_dir/raster_batch_test"
clang++ -std=c++20 -O1 -g -fsanitize=address,undefined -Wall -Wextra -Werror \
    "$repo_dir/tools/native_chromium_raster_batch_test.cpp" -o "$output_dir/raster_batch_sanitized_test"
"$output_dir/raster_batch_sanitized_test"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_graphite_shape_batch_test.cpp" -o "$output_dir/shape_batch_test"
"$output_dir/shape_batch_test" "$1" "$2"
