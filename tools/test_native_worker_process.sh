#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_WORKER_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-worker-process-test"}
mkdir -p "$output_dir"
case "$(uname -s)" in
    Darwin) js_flags="-framework JavaScriptCore" ;;
    Linux) js_flags=$(pkg-config --cflags --libs javascriptcoregtk-4.1) ;;
    *) echo "Unsupported native worker test platform" >&2; exit 1 ;;
esac
for mode in normal sanitized; do
    flags="-O2"
    if [ "$mode" = sanitized ]; then flags="-O1 -g -fsanitize=address,undefined"; fi
    clang -std=c11 $flags -Wall -Wextra -Werror -pthread \
        "$repo_dir/tools/native_worker_process_test.c" $js_flags \
        -o "$output_dir/worker-process-$mode"
    ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 \
        "$output_dir/worker-process-$mode" >"$output_dir/$mode.log" 2>&1
    cat "$output_dir/$mode.log"
done
