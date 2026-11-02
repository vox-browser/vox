#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_DIRECT_IMAGE_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-direct-image-test"}
mkdir -p "$output_dir"
for mode in release sanitized; do
    if [ "$mode" = sanitized ]; then
        flags="-O1 -g -fsanitize=address,undefined"
    else
        flags="-O2"
    fi
    clang++ -std=c++20 -Wall -Wextra -Werror $flags -I"$repo_dir" \
        "$repo_dir/tools/native_direct_image_raster_test.cpp" -o "$output_dir/$mode"
    "$output_dir/$mode"
done
