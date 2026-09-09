#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cases_file="$repo_dir/pixel_tests/cases.tsv"
output_dir=${PIXEL_TEST_OUTPUT_DIR:-"$repo_dir/Build/site-pixel-comparison"}
v_compiler=${V:-"$repo_dir/../v/v"}
diff_tool="$output_dir/pixel_diff"

if [ ! -x "$v_compiler" ]; then
    echo "V compiler not found: $v_compiler" >&2
    exit 2
fi

for requested in "$@"; do
    if ! awk -F '\t' -v name="$requested" '$1 == name { found = 1 } END { exit !found }' "$cases_file"; then
        echo "unknown pixel test: $requested" >&2
        exit 2
    fi
done

is_requested() {
    candidate=$1
    shift
    if [ "$requested_count" -eq 0 ]; then
        return 0
    fi
    for requested in "$@"; do
        if [ "$candidate" = "$requested" ]; then
            return 0
        fi
    done
    return 1
}

metric_percent() {
    metric_name=$1
    awk -v name="$metric_name" '$1 == name ":" { value = $3; gsub(/[()%]/, "", value); print value }'
}

metric_value() {
    metric_name=$1
    awk -v name="$metric_name" '$1 == name ":" { print $2 }'
}

within_limit() {
    actual=$1
    maximum=$2
    awk -v actual="$actual" -v maximum="$maximum" 'BEGIN { exit !(actual <= maximum) }'
}

mkdir -p "$output_dir"
"$v_compiler" -o "$diff_tool" "$repo_dir/tools/pixel_diff.v"

requested_count=$#
failures=0
executed=0
tab=$(printf '\t')
while IFS="$tab" read -r name fixture width height max_different max_over_3 max_over_10 max_rmse; do
    case "$name" in
        ''|'#'*) continue ;;
    esac
    if ! is_requested "$name" "$@"; then
        continue
    fi

    executed=$((executed + 1))
    expected="$repo_dir/pixel_tests/expected/$name.png"
    actual="$output_dir/$name.actual.png"
    diff="$output_dir/$name.diff.png"
    metrics_file="$output_dir/$name.metrics.txt"

    echo "[$name] ${width}x${height}"
    "$repo_dir/capture_screenshot.sh" "$repo_dir/pixel_tests/$fixture" "$actual" "$width" "$height"
    "$diff_tool" "$expected" "$actual" "$diff" > "$metrics_file"
    cat "$metrics_file"

    different=$(metric_percent different_pixels < "$metrics_file")
    over_3=$(metric_percent pixels_over_3 < "$metrics_file")
    over_10=$(metric_percent pixels_over_10 < "$metrics_file")
    rmse=$(metric_value rmse < "$metrics_file")

    case_failed=0
    for measurement in \
        "different_pixels $different $max_different" \
        "pixels_over_3 $over_3 $max_over_3" \
        "pixels_over_10 $over_10 $max_over_10" \
        "rmse $rmse $max_rmse"
    do
        measurement_name=${measurement%% *}
        measurement_values=${measurement#* }
        actual_value=${measurement_values%% *}
        maximum_value=${measurement_values#* }
        if ! within_limit "$actual_value" "$maximum_value"; then
            echo "FAIL $name: $measurement_name is $actual_value, limit is $maximum_value" >&2
            case_failed=1
        fi
    done
    if [ "$case_failed" -eq 0 ]; then
        echo "PASS $name"
    else
        failures=$((failures + 1))
    fi
done < "$cases_file"

if [ "$executed" -eq 0 ]; then
    echo "no pixel tests selected" >&2
    exit 2
fi
if [ "$failures" -ne 0 ]; then
    echo "$failures site pixel test(s) failed; inspect $output_dir/*.diff.png" >&2
    exit 1
fi
echo "All $executed site pixel test(s) passed."
