#!/bin/sh
set -eu
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "usage: $0 CONTROL_GRAPHITE_LIBRARY CANDIDATE_GRAPHITE_LIBRARY [CONTROL_SKIA_TEXT_LIBRARY]" >&2
    exit 2
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${NATIVE_GRAPHITE_TEST_OUTPUT_DIR:-"$repo_dir/Build/native-graphite-rounded-parts-test"}
mkdir -p "$output_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_graphite_shape_replay_test.cpp" \
    -o "$output_dir/native_graphite_shape_replay_test"
"$output_dir/native_graphite_shape_replay_test" "$1" "$2"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/native_graphite_rounded_parts_test.cpp" \
    -o "$output_dir/native_graphite_rounded_parts_test"
"$output_dir/native_graphite_rounded_parts_test" "$1" "$2"
if [ "$#" -eq 3 ]; then
    upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
    case "$(uname -m)" in
        arm64|aarch64) default_triplet=arm64-osx-dynamic ;;
        x86_64|amd64) default_triplet=x64-osx-dynamic ;;
        *) echo "Unsupported macOS architecture" >&2; exit 1 ;;
    esac
    skia_root="$upstream_dir/Build/release/vcpkg_installed/${LADYBIRD_VCPKG_TRIPLET:-$default_triplet}"
    graphite_dir=$(CDPATH= cd -- "$(dirname -- "$2")" && pwd)
    for name in native_skia_rounded_parts_test native_skia_solid_replay_test native_skia_sparse_layer_test; do
        clang++ -std=c++20 -O2 -x objective-c++ \
            -I"$skia_root/include/skia" -I"$skia_root/include" \
            "$repo_dir/tools/$name.cpp" \
            -L"$skia_root/lib" -lskia \
            -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
            -Wl,-rpath,"$skia_root/lib" -o "$output_dir/$name"
        VOX_SKIA_REFERENCE_LIBRARY="$3" DYLD_LIBRARY_PATH="$graphite_dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
            "$output_dir/$name"
    done
fi
