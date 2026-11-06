#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_SCROLL_RASTER_TEST_OUTPUT_DIR:-"$repo_dir/Build/scroll-raster-row-union"}
mkdir -p "$output_dir"
for mode in ordinary sanitized; do
    sanitize_flags=
    if [ "$mode" = sanitized ]; then
        sanitize_flags='-fsanitize=address,undefined -fno-omit-frame-pointer'
    fi
    clang -std=c11 -O2 $sanitize_flags "$repo_dir/tools/native_raster_row_ranges_test.c" \
        -o "$output_dir/ranges-$mode"
    ASAN_OPTIONS=detect_leaks=0 python3 "$repo_dir/tools/run_memory_bounded.py" --limit-gib 3 \
        --lock "$output_dir/ranges-$mode.lock" --report "$output_dir/ranges-$mode.json" -- \
        "$output_dir/ranges-$mode"
    clang -O2 $sanitize_flags -framework Cocoa -framework QuartzCore -framework IOSurface \
        "$repo_dir/tools/native_scroll_raster_row_union_test.m" -o "$output_dir/pixels-$mode"
    ASAN_OPTIONS=detect_leaks=0 python3 "$repo_dir/tools/run_memory_bounded.py" --limit-gib 3 \
        --lock "$output_dir/pixels-$mode.lock" --report "$output_dir/pixels-$mode.json" -- \
        "$output_dir/pixels-$mode"
    clang -O2 $sanitize_flags -framework Cocoa -framework QuartzCore -framework IOSurface \
        "$repo_dir/tools/native_scroll_raster_visible_copy_test.m" -o "$output_dir/visible-copy-$mode"
    ASAN_OPTIONS=detect_leaks=0 python3 "$repo_dir/tools/run_memory_bounded.py" --limit-gib 3 \
        --lock "$output_dir/visible-copy-$mode.lock" --report "$output_dir/visible-copy-$mode.json" -- \
        "$output_dir/visible-copy-$mode"
done
clang -O2 -framework Cocoa -framework QuartzCore -framework IOSurface \
    "$repo_dir/tools/test_scroll_raster_darwin.m" -o "$output_dir/scroll-regression"
python3 "$repo_dir/tools/run_memory_bounded.py" --limit-gib 3 \
    --lock "$output_dir/scroll-regression.lock" --report "$output_dir/scroll-regression.json" -- \
    "$output_dir/scroll-regression"
VOX_SKIP_OVERWRITTEN_SCROLL_COPY=1 python3 "$repo_dir/tools/run_memory_bounded.py" --limit-gib 3 \
    --lock "$output_dir/scroll-regression-visible.lock" --report "$output_dir/scroll-regression-visible.json" -- \
    "$output_dir/scroll-regression"
