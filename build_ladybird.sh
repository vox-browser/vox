#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bundle_dir="$repo_dir/Build/v/Ladybird.app"
binary_dir="$bundle_dir/Contents/MacOS"

v_compiler=${V_BIN:-}
if [ -z "$v_compiler" ]; then
    if command -v v >/dev/null 2>&1; then
        v_compiler=$(command -v v)
    else
        v_compiler=/Users/alex/code/v/v
    fi
fi

if [ ! -x "$v_compiler" ]; then
    echo "V compiler not found. Set V_BIN to an executable V compiler." >&2
    exit 1
fi

mkdir -p "$binary_dir"
cp "$repo_dir/packaging/Info.plist" "$bundle_dir/Contents/Info.plist"
# The translated LibWeb image plus Cocoa needs more static-root ranges than Boehm's default
# configuration. LARGE_CONFIG raises that supported table limit while retaining normal GC.
"$v_compiler" -enable-globals -prod -gc boehm_full_opt -cflags -DLARGE_CONFIG \
    -o "$binary_dir/Ladybird" "$repo_dir/main.v"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$bundle_dir" >/dev/null
fi

echo "Built V-native Ladybird app: $bundle_dir"
echo "Run: open '$bundle_dir'"
