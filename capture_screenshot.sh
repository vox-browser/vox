#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
browser="$repo_dir/Build/v/Ladybird.app/Contents/MacOS/Ladybird"

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    echo "usage: capture_screenshot.sh SOURCE OUTPUT.png [WIDTH [HEIGHT]]" >&2
    exit 2
fi

source=$1
output=$2
width=${3:-800}
height=${4:-600}
case "$width:$height" in
    *[!0-9:]*|0:*|*:0) echo "WIDTH and HEIGHT must be positive integers" >&2; exit 2 ;;
esac

if [ ! -x "$browser" ] || find "$repo_dir" \
    \( -path "$repo_dir/Build" -o -path "$repo_dir/.git" \) -prune -o \
    -type f \( -name '*.v' -o -name '*.m' \) ! -name '*_test.v' \
    ! -path "$repo_dir/tools/*" -newer "$browser" -print -quit | grep -q .; then
    "$repo_dir/build_ladybird.sh"
fi

capture_tmp=$(mktemp -d /tmp/ladybird-v-screenshot.XXXXXX)
cleanup() {
    rm -rf "$capture_tmp"
}
trap cleanup EXIT HUP INT TERM

# The native window includes 88px of toolbar and 24px of status chrome around the requested
# document viewport. The browser snapshots its Cocoa content view directly, avoiding macOS Screen
# Recording permission and excluding the title bar by construction.
window_height=$((height + 112))
if ! LADYBIRD_SCREENSHOT_DELAY_SECONDS="${SCREENSHOT_SETTLE_SECONDS:-2}" \
    "$browser" --window-width "$width" --window-height "$window_height" \
    --screenshot "$capture_tmp/window.png" "$source" >"$capture_tmp/browser.log" 2>&1; then
    cat "$capture_tmp/browser.log" >&2
    exit 1
fi
if [ ! -s "$capture_tmp/window.png" ]; then
    echo "Ladybird V did not produce a window screenshot" >&2
    cat "$capture_tmp/browser.log" >&2
    exit 1
fi
captured_width=$(sips -g pixelWidth "$capture_tmp/window.png" | awk '/pixelWidth/{print $2}')
captured_height=$(sips -g pixelHeight "$capture_tmp/window.png" | awk '/pixelHeight/{print $2}')
scale=$((captured_width / width))
if [ "$scale" -le 0 ] || [ $((width * scale)) -ne "$captured_width" ]; then
    echo "Unexpected captured window width: $captured_width for ${width}px viewport" >&2
    exit 1
fi

crop_top=$((88 * scale))
crop_width=$((width * scale))
crop_height=$((height * scale))
if [ "$captured_height" -ne $((window_height * scale)) ] \
    || [ $((crop_top + crop_height)) -gt "$captured_height" ]; then
    echo "Unexpected captured window geometry: ${captured_width}x${captured_height}" >&2
    exit 1
fi

mkdir -p "$(dirname "$output")"
sips --cropToHeightWidth "$crop_height" "$crop_width" --cropOffset "$crop_top" 0 \
    "$capture_tmp/window.png" --out "$capture_tmp/document.png" >/dev/null
if [ "$scale" -eq 1 ]; then
    cp "$capture_tmp/document.png" "$output"
else
    sips --resampleHeightWidth "$height" "$width" "$capture_tmp/document.png" \
        --out "$output" >/dev/null
fi
echo "Saved Ladybird V document screenshot: $output (${width}x${height})"
