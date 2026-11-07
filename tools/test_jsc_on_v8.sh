#!/bin/sh
# Differential check of the V8 backend's JavaScriptCore C API.
#
# Builds browserjs/v8/jsc_api_conformance_test.c against JavaScriptCore (with
# the Objective-C module loader) and against browserjs/v8/jsc_on_v8.cpp, runs
# both and requires identical output apart from lines starting with "engine".
# The V8 build also runs under AddressSanitizer/UndefinedBehaviorSanitizer.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
output_dir=${JSC_ON_V8_TEST_OUTPUT_DIR:-Build/jsc-on-v8-test}
v8_root=${VOX_V8_ROOT:-/opt/homebrew}
v8_runtime=
for candidate in "$v8_root"/lib/libnode.*.dylib; do
    if [ -f "$candidate" ]; then v8_runtime=$candidate; fi
done
if [ -z "$v8_runtime" ]; then
    echo "No libnode under $v8_root/lib (brew install node, or set VOX_V8_ROOT)" >&2
    exit 2
fi
rm -rf "$output_dir"
mkdir -p "$output_dir"
guard() {
    name=$1
    shift
    python3 tools/run_memory_bounded.py --limit-gib 3 \
        --lock "$output_dir/$name.lock" --report "$output_dir/$name.json" -- "$@"
}
test_source=browserjs/v8/jsc_api_conformance_test.c
guard jsc-compile clang -O1 -fobjc-arc -Wall -Werror -framework Foundation \
    -framework JavaScriptCore -framework CoreFoundation \
    "$test_source" browserjs/module_loader_darwin.m -o "$output_dir/jsc"
codesign --force --sign - --entitlements packaging/Vox.entitlements.plist "$output_dir/jsc"
for mode in optimized sanitized; do
    flags='-O2'
    if [ "$mode" = sanitized ]; then flags='-O1 -g -fsanitize=address,undefined -fno-sanitize=vptr'; fi
    mkdir -p "$output_dir/$mode"
    guard "$mode-library" clang++ -std=c++20 $flags -fPIC -dynamiclib -fvisibility=hidden -Wall -Werror \
        -I"$v8_root/include/node" -Ibrowserjs/v8/include browserjs/v8/jsc_on_v8.cpp "$v8_runtime" \
        -framework CoreFoundation -Wl,-rpath,"$v8_root/lib" \
        -Wl,-install_name,@rpath/libVoxJSCOnV8.dylib -o "$output_dir/$mode/libVoxJSCOnV8.dylib"
    guard "$mode-compile" clang $flags -Wall -Werror -Ibrowserjs/v8/include "$test_source" \
        -L"$output_dir/$mode" -lVoxJSCOnV8 -Wl,-rpath,"$output_dir/$mode" \
        -framework CoreFoundation -o "$output_dir/$mode/v8"
done
guard jsc-run "$output_dir/jsc" > "$output_dir/jsc.txt"
for mode in optimized sanitized; do
    ASAN_OPTIONS=detect_leaks=0 guard "$mode-run" "$output_dir/$mode/v8" > "$output_dir/$mode.txt"
    grep -v '^engine' "$output_dir/jsc.txt" > "$output_dir/jsc.compared"
    grep -v '^engine' "$output_dir/$mode.txt" > "$output_dir/$mode.compared"
    diff -u "$output_dir/jsc.compared" "$output_dir/$mode.compared"
done
echo "JavaScriptCore and V8 ($(grep '^engine:' "$output_dir/optimized.txt")) agree:" \
    "$(wc -l < "$output_dir/jsc.compared" | tr -d ' ') lines"
