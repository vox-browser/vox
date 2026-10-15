#!/bin/sh
set -eu

# Regenerate the checked-in macOS icon from its 1024px source. Browser builds
# copy the resulting .icns directly, without requiring the image tools.
if [ "$#" -ne 0 ]; then
    echo "usage: tools/build_app_icon.sh" >&2
    exit 2
fi

if [ "$(uname -s)" != Darwin ]; then
    echo "build_app_icon.sh requires macOS sips and iconutil" >&2
    exit 1
fi
for tool in sips iconutil; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found: $tool" >&2
        exit 1
    fi
done

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
icon_source="$repo_dir/packaging/Vox.png"
icon_output="$repo_dir/packaging/Vox.icns"
if [ ! -s "$icon_source" ]; then
    echo "Icon source not found: $icon_source" >&2
    exit 1
fi
icon_info=$(sips -g format -g pixelWidth -g pixelHeight "$icon_source")
icon_format=$(printf '%s\n' "$icon_info" | awk '/^[[:space:]]*format:/{print $2}')
icon_width=$(printf '%s\n' "$icon_info" | awk '/^[[:space:]]*pixelWidth:/{print $2}')
icon_height=$(printf '%s\n' "$icon_info" | awk '/^[[:space:]]*pixelHeight:/{print $2}')
if [ "$icon_format:$icon_width:$icon_height" != png:1024:1024 ]; then
    echo "Icon source must be a 1024x1024 PNG: $icon_source" >&2
    exit 1
fi

icon_tmp=$(mktemp -d "${TMPDIR:-/tmp}/vox-app-icon.XXXXXX")
cleanup() {
    rm -rf "$icon_tmp"
}
trap cleanup EXIT HUP INT TERM
iconset="$icon_tmp/Vox.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
    sips --resampleHeightWidth "$size" "$size" "$icon_source" \
        --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips --resampleHeightWidth "$retina_size" "$retina_size" "$icon_source" \
        --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$icon_tmp/Vox.icns" "$iconset"
mv "$icon_tmp/Vox.icns" "$icon_output"
echo "Generated macOS app icon: $icon_output"
