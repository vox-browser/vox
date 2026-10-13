#!/bin/sh
set -eu

# Build the optimized V-native browser as a macOS application bundle.
#
# Environment overrides:
#   V_BIN                     V compiler executable
#   LADYBIRD_V_GC            boehm (default) or none for ownership diagnostics
#   LADYBIRD_SOURCE_DIR       upstream Ladybird checkout used for Skia
#   LADYBIRD_VCPKG_TRIPLET    upstream vcpkg triplet directory

if [ "$(uname -s)" != "Darwin" ]; then
    echo "build-prod-browser.sh builds a macOS .app and must run on macOS" >&2
    exit 1
fi

if [ "$#" -ne 0 ]; then
    echo "usage: build-prod-browser.sh" >&2
    exit 2
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
build_dir="$repo_dir/Build/v"
bundle_dir="$build_dir/Ladybird.app"
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

# Page parsing, intrinsic measurement, animation and input updates allocate
# temporary V data. Reclaim that data in the interactive browser; the no-GC
# mode remains available for explicit heap-ownership diagnostics.
gc_mode=${LADYBIRD_V_GC:-boehm}
case "$gc_mode" in
    boehm|none) ;;
    *)
        echo "LADYBIRD_V_GC must be boehm or none" >&2
        exit 2
        ;;
esac

# LibRegex's translated C++ wrappers reuse the same pinned Rust backend as
# upstream. Build the repository-owned archive before compiling the browser.
python3 "$repo_dir/tools/build_regex_backend.py"

case "$(uname -m)" in
    arm64|aarch64) default_vcpkg_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_vcpkg_triplet=x64-osx-dynamic ;;
    *)
        echo "Unsupported macOS architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

mkdir -p "$binary_dir"
cp "$repo_dir/packaging/Info.plist" "$bundle_dir/Contents/Info.plist"

extra_cflags=""
if [ "$gc_mode" = boehm ]; then
    # The compatibility compiler's source-built collector has only 2048
    # static-root ranges. AppKit/Metal's dyld images exceed that limit; match
    # the large configuration used by current V and its macOS GC archives.
    extra_cflags="-DLARGE_CONFIG=1"
fi
extra_ldflags=""
upstream_dir=${LADYBIRD_SOURCE_DIR:-"$repo_dir/../3rd/ladybird"}
vcpkg_triplet=${LADYBIRD_VCPKG_TRIPLET:-$default_vcpkg_triplet}
skia_root="$upstream_dir/Build/release/vcpkg_installed/$vcpkg_triplet"
rust_cargo=${RUST_CARGO:-}
if [ -z "$rust_cargo" ]; then
    if command -v cargo >/dev/null 2>&1; then
        rust_cargo=$(command -v cargo)
    elif [ -x /opt/homebrew/opt/rustup/bin/cargo ]; then
        rust_cargo=/opt/homebrew/opt/rustup/bin/cargo
    fi
fi
if [ -n "$rust_cargo" ]; then
    rust_target_dir="$build_dir/rust-yuv"
    PATH="$(dirname "$rust_cargo"):$PATH" CARGO_TARGET_DIR="$rust_target_dir" \
        "$rust_cargo" build --quiet --release --locked \
        --manifest-path "$repo_dir/native_yuv_rust/Cargo.toml"
    extra_cflags="$extra_cflags -DLADYBIRD_V_HAS_RUST_YUV"
    extra_ldflags="$extra_ldflags -L$rust_target_dir/release -lladybird_v_yuv"
fi
if [ -f "$skia_root/lib/libskia.dylib" ] && [ -d "$skia_root/include/skia/include" ]; then
    bridge_library="$build_dir/libLadybirdVSkiaText.dylib"
    clang++ -std=c++20 -O2 -fPIC -dynamiclib -x objective-c++ \
		-I"$skia_root/include/skia" -I"$skia_root/include" \
		"$repo_dir/native_skia_text_darwin.cpp" \
        -L"$skia_root/lib" -lskia \
        -framework CoreFoundation -framework CoreGraphics -framework Foundation \
        -Wl,-rpath,"$skia_root/lib" \
        -Wl,-install_name,@rpath/libLadybirdVSkiaText.dylib \
        -o "$bridge_library"
    extra_cflags="$extra_cflags -DLADYBIRD_V_HAS_SKIA_TEXT"
    extra_ldflags="$extra_ldflags -L$build_dir -lLadybirdVSkiaText -Wl,-rpath,$build_dir -Wl,-rpath,$skia_root/lib -lc++"
fi
if [ -f "$skia_root/lib/libavformat.dylib" ] && [ -f "$skia_root/include/libavformat/avformat.h" ]; then
    extra_cflags="$extra_cflags -DLADYBIRD_V_HAS_FFMPEG -I$skia_root/include"
    # Adding the vcpkg include root also selects that ICU's versioned C API
    # declarations in the LibUnicode bridges, so link its matching runtime.
    extra_ldflags="$extra_ldflags -L$skia_root/lib -lavformat -lavcodec -lswscale -lswresample -lavutil -lyuv -licuuc -Wl,-rpath,$skia_root/lib"
fi

# This V checkout currently selects both the C and native `time.zoneinfo`
# backends for this large single-file build. Excluding the native backend keeps
# the normal macOS C implementation and avoids duplicate method definitions.
zoneinfo_exclude='@vlib/time/zoneinfo.native.v'

# The translated tree is validated with V's stable compatibility compiler.
# Select the same frontend explicitly so a newer default compiler on PATH does
# not turn a browser build into an unrelated source-migration attempt.
# This compatibility compiler's -prod mode snapshots every pointer in live
# aggregates around calls. Growing CSS token arrays are traversed on every
# token, turning linear parsing into quadratic work. Use a fully scanned heap
# and optimize the generated C directly instead. Full scanning keeps nested
# strings/arrays reachable without those expensive snapshots.
set -- -old-compiler -exclude "$zoneinfo_exclude" -enable-globals
if [ "$gc_mode" = boehm ]; then
    set -- "$@" -gc boehm_full
    extra_cflags="$extra_cflags -O2"
else
    set -- "$@" -prod -gc none
fi
echo "Building Ladybird V with: $* -cflags $extra_cflags"
# Root browser features are split across main.v and companion module files.
cd "$repo_dir"
if [ -n "$extra_ldflags" ]; then
    "$v_compiler" "$@" \
        -cflags "$extra_cflags" -ldflags "$extra_ldflags" \
        -o "$binary_dir/Ladybird" .
else
    "$v_compiler" "$@" \
        -cflags "$extra_cflags" \
        -o "$binary_dir/Ladybird" .
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$bundle_dir" >/dev/null
fi

echo "Built production Ladybird V app: $bundle_dir"
echo "Run: open '$bundle_dir'"
