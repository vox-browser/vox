#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bundle_dir="$repo_dir/Build/v/Ladybird.app"
binary_dir="$bundle_dir/Contents/MacOS"
build_dir="$repo_dir/Build/v"

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
extra_cflags=""
extra_ldflags=""
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
skia_root="$upstream_dir/Build/release/vcpkg_installed/arm64-osx-dynamic"
if [ -f "$skia_root/lib/libskia.dylib" ] && [ -d "$skia_root/include/skia/include" ]; then
    bridge_library="$build_dir/libLadybirdVSkiaText.dylib"
	clang++ -std=c++20 -O2 -fPIC -dynamiclib -x objective-c++ -I"$skia_root/include/skia" \
		"$repo_dir/native_skia_text_darwin.cpp" -L"$skia_root/lib" -lskia \
		-framework CoreFoundation -framework CoreGraphics -framework Foundation \
		-Wl,-rpath,"$skia_root/lib" \
        -Wl,-install_name,@rpath/libLadybirdVSkiaText.dylib -o "$bridge_library"
    extra_cflags="$extra_cflags -DLADYBIRD_V_HAS_SKIA_TEXT"
    extra_ldflags="-L$build_dir -lLadybirdVSkiaText -Wl,-rpath,$build_dir -Wl,-rpath,$skia_root/lib -lc++"
fi
if [ -n "$extra_ldflags" ]; then
	"$v_compiler" -enable-globals -prod -gc none -cflags "$extra_cflags" \
		-ldflags "$extra_ldflags" -o "$binary_dir/Ladybird" "$repo_dir/main.v"
else
	"$v_compiler" -enable-globals -prod -gc none -cflags "$extra_cflags" \
		-o "$binary_dir/Ladybird" "$repo_dir/main.v"
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$bundle_dir" >/dev/null
fi

echo "Built V-native Ladybird app: $bundle_dir"
echo "Run: open '$bundle_dir'"
