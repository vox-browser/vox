#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
if [ -n "${V_BIN:-}" ]; then
    v_compiler=$V_BIN
elif command -v v >/dev/null 2>&1; then
    v_compiler=$(command -v v)
else
    v_compiler="$repo_dir/../v/v"
fi
output_dir=${SCREENSHOT_OUTPUT_DIR:-"$repo_dir/Build/comparisons"}
layout_test_font=${LADYBIRD_LAYOUT_TEST_FONT:-"$upstream_dir/Base/res/fonts/SerenitySans-Regular.ttf"}

if [ ! -x "$v_compiler" ]; then
    echo "V compiler not found. Set V_BIN to an executable V compiler." >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    set -- inline-node ordered-list text-decorations
fi

mkdir -p "$output_dir"

for requested in "$@"; do
    case "$requested" in
        */*) input_path=$requested ;;
        *) input_path="$upstream_dir/Tests/LibWeb/Screenshot/input/$requested.html" ;;
    esac
    if [ ! -f "$input_path" ]; then
        echo "Screenshot input not found: $input_path" >&2
        exit 1
    fi
    name=$(basename "$input_path" .html)
    expected_path="$upstream_dir/Tests/LibWeb/Screenshot/expected/$name.png"
    if [ ! -f "$expected_path" ]; then
        echo "Upstream screenshot reference not found: $expected_path" >&2
        exit 1
    fi

    actual_path="$output_dir/$name.actual.png"
    diff_path="$output_dir/$name.diff.png"
    width=$(sips -g pixelWidth "$expected_path" | awk '/pixelWidth/{print $2}')
    height=$(sips -g pixelHeight "$expected_path" | awk '/pixelHeight/{print $2}')

    LADYBIRD_LAYOUT_TEST_FONT="$layout_test_font" \
        "$repo_dir/capture_screenshot.sh" "$input_path" "$actual_path" "$width" "$height"

    echo "== $name =="
    "$v_compiler" run "$repo_dir/tools/pixel_diff.v" "$expected_path" "$actual_path" "$diff_path"
done

echo "Comparison artifacts: $output_dir"
