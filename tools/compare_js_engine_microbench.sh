#!/bin/sh
# Engine-only comparison: tools/js_engine_microbench.c against JavaScriptCore
# and against the V8 backend, alternating processes for ROUNDS rounds.
# usage: tools/compare_js_engine_microbench.sh [ROUNDS] [RUNS_PER_WORKLOAD]
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
rounds=${1:-3}
runs=${2:-5}
output_dir=${JS_ENGINE_MICROBENCH_OUTPUT_DIR:-Build/js-engine-microbench}
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
clang -O2 -Wall -Werror -framework JavaScriptCore tools/js_engine_microbench.c -o "$output_dir/jsc"
codesign --force --sign - --entitlements packaging/Vox.entitlements.plist "$output_dir/jsc"
clang++ -std=c++20 -O3 -fPIC -dynamiclib -fvisibility=hidden -I"$v8_root/include/node" -Ibrowserjs/v8/include \
    browserjs/v8/jsc_on_v8.cpp "$v8_runtime" -framework CoreFoundation -Wl,-rpath,"$v8_root/lib" \
    -Wl,-install_name,@rpath/libVoxJSCOnV8.dylib -o "$output_dir/libVoxJSCOnV8.dylib"
clang -O2 -Wall -Werror -Ibrowserjs/v8/include tools/js_engine_microbench.c -L"$output_dir" -lVoxJSCOnV8 \
    -Wl,-rpath,"$output_dir" -framework CoreFoundation -o "$output_dir/v8"
round=1
while [ "$round" -le "$rounds" ]; do
    if [ $((round % 2)) = 1 ]; then order="jsc v8"; else order="v8 jsc"; fi
    for engine in $order; do
        python3 tools/run_memory_bounded.py --limit-gib 3 --lock "$output_dir/$engine-$round.lock" \
            --report "$output_dir/$engine-$round-guard.json" -- "$output_dir/$engine" "$runs" \
            | sed "s/^{/{\"round\": $round, /" | tee -a "$output_dir/results.jsonl"
    done
    round=$((round + 1))
done
