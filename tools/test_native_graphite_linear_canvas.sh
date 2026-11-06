#!/bin/sh
# Run through tools/run_memory_bounded.py --limit-gib 3.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skia_source="$repo_dir/Build/deps/skia-brave/source"
output_dir=${NATIVE_GRAPHITE_LINEAR_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-graphite-linear-canvas"}
mkdir -p "$output_dir"
for mode in optimized sanitized; do
    flags=-O2
    if [ "$mode" = sanitized ]; then flags='-O1 -g -fsanitize=address,undefined'; fi
    clang++ -std=c++20 $flags -DSK_GRAPHITE -DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER \
        -I"$skia_source" "$repo_dir/tools/native_graphite_linear_canvas_test.mm" \
        -L"$skia_source/out/Release" -lskia -lskcms \
        -framework Foundation -framework Metal -framework CoreGraphics -framework ImageIO -framework IOSurface \
        -o "$output_dir/$mode"
    "$output_dir/$mode"
    # Exercise the same pixel/ownership/failure references with the completed
    # render submitted before the following IOSurface-copy encoder work.
    VOX_GPU_TILE_EARLY_RENDER_SUBMIT=1 "$output_dir/$mode"
    VOX_GPU_TILE_DEFER_SCHEDULE_WAIT=1 "$output_dir/$mode"
    VOX_GPU_TILE_EARLY_RENDER_SUBMIT=1 VOX_GPU_TILE_DEFER_SCHEDULE_WAIT=1 "$output_dir/$mode"
done
