#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
output_dir=${NATIVE_MODULE_SCRIPT_CACHE_TEST_OUTPUT_DIR:-Build/native-module-script-cache}
mkdir -p "$output_dir"
for mode in arc mrc sanitized-arc sanitized-mrc; do
    flags='-O2'
    case "$mode" in sanitized-*) flags='-O1 -g -fsanitize=address,undefined';; esac
    case "$mode" in *-arc|arc) flags="$flags -fobjc-arc";; esac
    python3 tools/run_memory_bounded.py --limit-gib 3 \
        --lock "$output_dir/$mode-compile.lock" --report "$output_dir/$mode-compile.json" -- \
        clang -Wall -Wextra -Werror $flags -framework Foundation -framework JavaScriptCore \
        tools/native_module_script_cache_test.m -o "$output_dir/$mode"
    codesign --force --sign - --entitlements packaging/Vox.entitlements.plist "$output_dir/$mode"
    python3 tools/run_memory_bounded.py --limit-gib 3 \
        --lock "$output_dir/$mode-run.lock" --report "$output_dir/$mode-run.json" -- "$output_dir/$mode"
done
