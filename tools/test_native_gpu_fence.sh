#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_GPU_FENCE_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-gpu-fence"}
mkdir -p "$output_dir"
for mode in optimized sanitized arc; do
    flags=-O2
    if [ "$mode" = sanitized ]; then flags='-O1 -g -fsanitize=address,undefined'; fi
    if [ "$mode" = arc ]; then flags='-O2 -fobjc-arc'; fi
    clang++ -std=c++20 $flags "$repo_dir/tools/native_gpu_fence_test.mm" \
        -framework Cocoa -framework QuartzCore -framework IOSurface -o "$output_dir/$mode"
    "$output_dir/$mode"
done
