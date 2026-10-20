#!/bin/sh
set -eu

if [ "$#" -ne 0 ] && [ "$#" -ne 2 ]; then
    echo "usage: $0 [UNCACHED_GRAPHITE_LIBRARY CACHED_GRAPHITE_LIBRARY]" >&2
    exit 2
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_GRAPHITE_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-graphite-cache-test"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_graphite_raster_cache_test.cpp" \
    -o "$output_dir/native_graphite_raster_cache_test"
"$output_dir/native_graphite_raster_cache_test"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_graphite_shadow_cache_test.cpp" \
    -o "$output_dir/native_graphite_shadow_cache_test"
"$output_dir/native_graphite_shadow_cache_test"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_graphite_solid_rect_test.cpp" \
    -o "$output_dir/native_graphite_solid_rect_test"
"$output_dir/native_graphite_solid_rect_test"

if [ "$#" -eq 2 ]; then
    clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
        "$repo_dir/tools/native_graphite_raster_replay_test.cpp" \
        -o "$output_dir/native_graphite_raster_replay_test"
    "$output_dir/native_graphite_raster_replay_test" "$1" "$2"
fi
