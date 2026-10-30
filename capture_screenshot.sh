#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
browser="$repo_dir/Build/v/Vox.app/Contents/MacOS/Vox"

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

# Callers that pin a completed shared bundle can test it while newer source
# changes are being built elsewhere. They remain responsible for its identity.
if [ "${SCREENSHOT_REUSE_PRODUCTION:-0}" != 1 ]; then
if [ ! -x "$browser" ] \
    || [ ! -f "$repo_dir/Build/v/Vox.app/Contents/Resources/Vox.icns" ] \
    || [ ! -f "$repo_dir/Build/v/Vox.app/Contents/Resources/adblock.snapshot.bin" ] \
    || [ "$repo_dir/adblock/engine.snapshot.bin" -nt "$browser" ] \
    || [ "$repo_dir/browserhistory/history.css" -nt "$browser" ] \
    || [ "$repo_dir/packaging/Info.plist" -nt "$browser" ] \
    || [ "$repo_dir/packaging/Vox.icns" -nt "$browser" ] \
    || [ "$repo_dir/build-prod-browser.sh" -nt "$browser" ] \
    || [ "$repo_dir/tools/prepare_http_compat.py" -nt "$browser" ] \
    || [ "$repo_dir/tools/prepare_ui2.py" -nt "$browser" ] \
    || [ "$repo_dir/tools/ui2/embedded_browser_darwin.v" -nt "$browser" ] \
    || [ "$repo_dir/native_address_bar_darwin.h" -nt "$browser" ] \
    || find "$repo_dir" \
    \( -path "$repo_dir/Build" -o -path "$repo_dir/.git" \) -prune -o \
    -type f \( -name '*.v' -o -name '*.m' -o -name '*.cpp' -o -name '*.h' \) ! -name '*_test.v' \
    ! -path "$repo_dir/tools/*" -newer "$browser" -print -quit | grep -q .; then
    "$repo_dir/build_ladybird.sh"
fi
fi
if [ ! -x "$browser" ]; then
    echo "Production browser is missing: $browser" >&2
    exit 1
fi

capture_tmp=$(mktemp -d /tmp/ladybird-v-screenshot.XXXXXX)
cleanup() {
    rm -rf "$capture_tmp"
}
trap cleanup EXIT HUP INT TERM

# Persisted browser chrome (for example a visible bookmarks bar) changes the
# document viewport and invalidates the fixed chrome crop below. Give each
# capture an empty profile, including every strip of a stitched capture.
VOX_PROFILE_DIR="$capture_tmp/profile"
export VOX_PROFILE_DIR

# The native window includes a 60px integrated tab strip and toolbar (diagnostics hidden) and 24px status bar around the requested
# document viewport. The browser snapshots its Cocoa content view directly, avoiding macOS Screen
# Recording permission including the integrated window controls in the cropped browser chrome.
toolbar_height=60
chrome_height=$((toolbar_height + 24))
window_height=$((height + chrome_height))
launch_window_height=$window_height
needs_stitching=0
# Start stitching conservatively before an AppKit window can hit the visible
# screen's height cap. The exact cap depends on the menu bar and Dock, so a
# fixed 1200px cut-over was too late on 1117px-high displays: a 980px viewport
# was silently shortened and its status bar ended up inside the document crop.
if [ "$launch_window_height" -gt 1000 ]; then
	launch_window_height=1000
	needs_stitching=1
elif [ "${LADYBIRD_SCREENSHOT_STITCH:-0}" = 1 ]; then
	# A shorter display capped an ordinary capture; the first strip below
	# discovers the cap.
	needs_stitching=1
fi
if [ "$needs_stitching" -eq 1 ]; then
    if ! command -v magick >/dev/null 2>&1; then
        echo "ImageMagick is required to stitch a tall off-screen capture" >&2
        exit 1
    fi

    # AppKit limits an on-screen window to the display, but the engine must
	# still lay out against the full requested viewport (not one viewport per
	# strip). Keep the window at 1000px, below the display-dependent AppKit cap,
	# and stitch only non-overlapping document ranges. The final strip starts at
	# the maximum scroll offset, so the bottom of the logical viewport is retained.
    segment_height=$((launch_window_height - chrome_height))
    max_scroll=$((height - segment_height))
    if [ "$max_scroll" -lt 0 ]; then
        max_scroll=0
    fi
    assembled="$capture_tmp/assembled.png"
    logical_y=0
    segment_index=0
    while [ "$logical_y" -lt "$height" ]; do
        scroll_y=$logical_y
        if [ "$scroll_y" -gt "$max_scroll" ]; then
            scroll_y=$max_scroll
        fi
        local_y=$((logical_y - scroll_y))
        take=$((segment_height - local_y))
        remaining=$((height - logical_y))
        if [ "$take" -gt "$remaining" ]; then
            take=$remaining
        fi
        window_png="$capture_tmp/window-$segment_index.png"
        attempt=1
        while [ "$attempt" -le 2 ] && [ ! -s "$window_png" ]; do
            if ! LADYBIRD_SCREENSHOT_DELAY_SECONDS="${SCREENSHOT_SETTLE_SECONDS:-2}" \
                "$browser" --window-width "$width" --window-height "$launch_window_height" \
                --screenshot-viewport-height "$height" --screenshot-scroll-y "$scroll_y" \
                --screenshot "$window_png" "$source" >"$capture_tmp/browser-$segment_index.log" 2>&1; then
                cat "$capture_tmp/browser-$segment_index.log" >&2
                exit 1
            fi
            attempt=$((attempt + 1))
        done
        if [ ! -s "$window_png" ]; then
            echo "Ladybird V did not produce tall screenshot strip $segment_index" >&2
            cat "$capture_tmp/browser-$segment_index.log" >&2
            exit 1
        fi
        captured_width=$(sips -g pixelWidth "$window_png" | awk '/pixelWidth/{print $2}')
        captured_height=$(sips -g pixelHeight "$window_png" | awk '/pixelHeight/{print $2}')
        scale=$((captured_width / width))
        if [ "$scale" -le 0 ] || [ $((width * scale)) -ne "$captured_width" ]; then
            echo "Unexpected tall screenshot strip width: $captured_width" >&2
            exit 1
        fi
        if [ "$segment_index" -eq 0 ]; then
            captured_logical_height=$((captured_height / scale))
            if [ "$captured_logical_height" -lt "$launch_window_height" ]; then
                # AppKit scaled the oversized probe into the visible screen.
                # Relaunch at the discovered cap; otherwise both Y coordinates
                # and the browser status bar would be compressed in every strip.
                launch_window_height=$captured_logical_height
                segment_height=$((captured_logical_height - chrome_height))
                if [ "$segment_height" -le 0 ]; then
                    echo "Captured window leaves no document viewport" >&2
                    exit 1
                fi
                max_scroll=$((height - segment_height))
                if [ "$max_scroll" -lt 0 ]; then
                    max_scroll=0
                fi
                rm -f "$window_png"
                continue
            fi
        fi
        required_height=$(((toolbar_height + local_y + take) * scale))
        if [ "$captured_height" -lt "$required_height" ]; then
            echo "Unexpected tall screenshot strip geometry: ${captured_width}x${captured_height}" >&2
            exit 1
        fi
        chunk="$capture_tmp/chunk-$segment_index.png"
        magick "$window_png" -crop "$((width * scale))x$((take * scale))+0+$(((toolbar_height + local_y) * scale))" \
            +repage -resize "${width}x${take}!" "$chunk"
        if [ "$segment_index" -eq 0 ]; then
            cp "$chunk" "$assembled"
        else
            next_assembled="$capture_tmp/assembled-$segment_index.png"
            magick "$assembled" "$chunk" -append "$next_assembled"
            assembled=$next_assembled
        fi
        logical_y=$((logical_y + take))
        segment_index=$((segment_index + 1))
    done
    mkdir -p "$(dirname "$output")"
    cp "$assembled" "$output"
    echo "Saved Ladybird V stitched document screenshot: $output (${width}x${height}, ${segment_index} strips)"
    exit 0
fi
attempt=1
while [ "$attempt" -le 2 ]; do
    rm -f "$capture_tmp/window.png"
    if LADYBIRD_SCREENSHOT_DELAY_SECONDS="${SCREENSHOT_SETTLE_SECONDS:-2}" \
        "$browser" --window-width "$width" --window-height "$launch_window_height" \
        --screenshot "$capture_tmp/window.png" "$source" >"$capture_tmp/browser.log" 2>&1; then
        break
    fi
    if [ "$attempt" -eq 2 ]; then
        cat "$capture_tmp/browser.log" >&2
        exit 1
    fi
    attempt=$((attempt + 1))
done
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

crop_top=$((toolbar_height * scale))
crop_width=$((width * scale))
crop_height=$((height * scale))
expected_window_height=$((window_height * scale))
capture_source="$capture_tmp/window.png"
if [ "$captured_height" -lt "$expected_window_height" ]; then
    if [ "${LADYBIRD_SCREENSHOT_STITCH:-0}" != 1 ]; then
        # AppKit limits the window to the visible screen. Capture the
        # viewport in strips at that height instead.
        trap - EXIT HUP INT TERM
        cleanup
        LADYBIRD_SCREENSHOT_STITCH=1 exec "$0" "$@"
    fi
    echo "Unexpected captured window height: $captured_height (expected $expected_window_height)" >&2
    exit 1
fi
if [ "$captured_height" -ne "$expected_window_height" ] \
    || [ $((crop_top + crop_height)) -gt "$captured_height" ]; then
    echo "Unexpected captured window geometry: ${captured_width}x${captured_height}" >&2
    exit 1
fi

mkdir -p "$(dirname "$output")"
sips --cropToHeightWidth "$crop_height" "$crop_width" --cropOffset "$crop_top" 0 \
    "$capture_source" --out "$capture_tmp/document.png" >/dev/null
if [ "$scale" -eq 1 ]; then
    cp "$capture_tmp/document.png" "$output"
else
    sips --resampleHeightWidth "$height" "$width" "$capture_tmp/document.png" \
        --out "$output" >/dev/null
fi
echo "Saved Ladybird V document screenshot: $output (${width}x${height})"
