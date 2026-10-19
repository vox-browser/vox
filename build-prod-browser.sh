#!/bin/sh
set -eu

# Build the optimized V-native browser for the current desktop platform.
#
# Environment overrides:
#   V_BIN                     V compiler executable
#   UI2_SOURCE_DIR            UI2 checkout (defaults to ~/.vmodules/ui2)
#   LADYBIRD_V_GC            boehm (default), boehm_full, prealloc, or none
#   LADYBIRD_V_PROFILE       V profiling report path (unset for normal builds)
#   LADYBIRD_V_PROFILE_FNS   comma-separated C function names to profile
#   LADYBIRD_SOURCE_DIR       upstream Ladybird checkout used for Skia
#   LADYBIRD_VCPKG_TRIPLET    upstream vcpkg triplet directory

case "$(uname -s)" in
    Linux) exec sh "$(dirname -- "$0")/build-linux-browser.sh" "$@" ;;
    Darwin) ;;
    *) echo "Vox supports macOS and Linux" >&2; exit 1 ;;
esac

if [ "$#" -ne 0 ]; then
    echo "usage: build-prod-browser.sh" >&2
    exit 2
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
build_dir="$repo_dir/Build/v"
bundle_dir="$build_dir/Vox.app"
binary_dir="$bundle_dir/Contents/MacOS"
resources_dir="$bundle_dir/Contents/Resources"

v_compiler=${V_BIN:-}
if [ -z "$v_compiler" ]; then
    if command -v v >/dev/null 2>&1; then
        v_compiler=$(command -v v)
    else
        v_compiler="$HOME/code/v/v"
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
    boehm|boehm_full|prealloc|none) ;;
    *)
        echo "LADYBIRD_V_GC must be boehm, boehm_full, prealloc, or none" >&2
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

mkdir -p "$binary_dir" "$resources_dir"
cp "$repo_dir/packaging/Info.plist" "$bundle_dir/Contents/Info.plist"
cp "$repo_dir/packaging/Vox.icns" "$resources_dir/Vox.icns"
snapshot_resource_tmp=$(mktemp "$resources_dir/.adblock-snapshot.XXXXXX")
cp "$repo_dir/adblock/engine.snapshot.bin" "$snapshot_resource_tmp"
chmod 644 "$snapshot_resource_tmp"
mv -f "$snapshot_resource_tmp" "$resources_dir/adblock.snapshot.bin"

extra_cflags=""
if [ "$gc_mode" = boehm ] || [ "$gc_mode" = boehm_full ]; then
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
bridge_library=""
graphite_library=""
dawn_library=""
if [ -f "$skia_root/lib/libskia.dylib" ] && [ -d "$skia_root/include/skia/include" ]; then
    graphite_library="$build_dir/libVoxGraphite.dylib"
    if [ -n "${VOX_PRIVATE_GRAPHITE_HELPER:-}" ]; then
        python3 "$VOX_PRIVATE_GRAPHITE_HELPER" --repo "$repo_dir" \
            --skia-root "$skia_root" --output "$graphite_library"
    else
        python3 "$repo_dir/tools/build_mac_graphite.py" --skia-root "$skia_root" \
            --output "$graphite_library"
    fi
    dawn_library="$build_dir/libVoxGraphiteDawn.dylib"
    python3 "$repo_dir/tools/build_mac_graphite_dawn.py" --skia-root "$skia_root" \
        --output "$dawn_library"
    bridge_library="$build_dir/libLadybirdVSkiaText.dylib"
    clang++ -std=c++20 -O2 -fPIC -dynamiclib -x objective-c++ \
		-I"$skia_root/include/skia" -I"$skia_root/include" \
		"$repo_dir/native_skia_text_darwin.cpp" \
        -L"$skia_root/lib" -lskia \
        -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal \
        -Wl,-rpath,"$skia_root/lib" \
        -Wl,-install_name,@rpath/libLadybirdVSkiaText.dylib \
        -o "$bridge_library"
    extra_cflags="$extra_cflags -DLADYBIRD_V_HAS_SKIA_TEXT"
    extra_ldflags="$extra_ldflags -L$build_dir -lLadybirdVSkiaText -Wl,-rpath,@executable_path -Wl,-rpath,$skia_root/lib -lc++"
fi
if [ -f "$skia_root/lib/libavformat.dylib" ] && [ -f "$skia_root/include/libavformat/avformat.h" ]; then
    extra_cflags="$extra_cflags -DLADYBIRD_V_HAS_FFMPEG -I$skia_root/include"
    # Adding the vcpkg include root also selects that ICU's versioned C API
    # declarations in the LibUnicode bridges, so link its matching runtime.
    # Codec entry points load on first use through native_ffmpeg_darwin.h.
    extra_ldflags="$extra_ldflags -L$skia_root/lib -licuuc -Wl,-rpath,$skia_root/lib"
fi

# This V checkout currently selects both the C and native `time.zoneinfo`
# backends for this large single-file build. Excluding the native backend keeps
# the normal macOS C implementation and avoids duplicate method definitions.
zoneinfo_exclude='@vlib/time/zoneinfo.native.v'

# Build with the current V compiler. Its driver otherwise retries a failed
# build with the 0.5.2 compatibility compiler, which would silently produce a
# browser from a different frontend; fail instead.
V_MACOS_V3_NO_FALLBACK=1
export V_MACOS_V3_NO_FALLBACK
# The compatibility compiler's -prod mode snapshotted every pointer in live
# aggregates around calls, turning CSS token parsing quadratic. Optimize the
# generated C directly instead. Pointer-aware Boehm traces the live object
# graph while leaving pointer-free buffers atomic. Optimized forced-GC tests
# cover nested token strings, CSSOM values and arena records. boehm_full
# remains available as an ownership diagnostic.
ui2_modules=$(python3 "$repo_dir/tools/prepare_ui2.py" "$v_compiler")
http_modules=$(python3 "$repo_dir/tools/prepare_http_compat.py" "$v_compiler")
# Anchor package names at the repository; see build-linux-browser.sh. Without
# it, a checkout under `modules`, `.vmodules`, `vlib` or another v.mod compiles
# `encoding` as `vox2.encoding` while imports still resolve to vlib's name.
set -- -exclude "$zoneinfo_exclude" -enable-globals \
    -d vox_ui2 -path "$repo_dir|$http_modules|$ui2_modules|@vmodules|@vlib"
if [ "${VOX_KEEP_C:-0}" = 1 ]; then
    set -- "$@" -keepc
fi
if [ "${VOX_DOCUMENT_RETENTION_DIAGNOSTICS:-0}" = 1 ]; then
    set -- "$@" -d vox_document_retention_diagnostics
fi
if [ "${VOX_PHASE_DIAGNOSTICS:-0}" = 1 ]; then
    set -- "$@" -d vox_phase_diagnostics
fi
if [ "${VOX_CSS_DIAGNOSTICS:-0}" = 1 ]; then
    set -- "$@" -d vox_css_diagnostics
fi
if [ "$gc_mode" = prealloc ] && [ "${VOX_PREALLOC_SAMPLER:-0}" = 1 ]; then
    # Diagnostic build: sample the sites of never-reclaimed allocations
    # (tools/prealloc_allocation_sampler.c). Needs the allocator hook in V's
    # prealloc arena.
    set -- "$@" -d prealloc_alloc_hook
    mkdir -p "$repo_dir/Build/v"
    sampler_object="$repo_dir/Build/v/prealloc_allocation_sampler.o"
    cc -O2 -c "$repo_dir/tools/prealloc_allocation_sampler.c" -o "$sampler_object"
    extra_ldflags="$extra_ldflags $sampler_object"
fi
if [ "$gc_mode" = prealloc ]; then
    # Thread-local bump arenas without a collector; V's free() is a no-op.
    # -prealloc leaves V's default collector selected, so deselect it too.
    set -- "$@" -prealloc -gc none
    extra_cflags="$extra_cflags -O2"
elif [ "$gc_mode" != none ]; then
    set -- "$@" -gc "$gc_mode"
    extra_cflags="$extra_cflags -O2"
else
    set -- "$@" -prod -gc none
fi
if [ -n "${LADYBIRD_V_PROFILE:-}" ]; then
    set -- "$@" -profile "$LADYBIRD_V_PROFILE" -profile-no-inline \
        -profile-fns "${LADYBIRD_V_PROFILE_FNS:-main__BrowserApp_install_loaded_page,layout__run_document_layout_with_renderer_mode}"
    # V emits profiling stdio calls ahead of the macOS stdio declarations.
    # Include those declarations first, without fortified function-like macros
    # that would rewrite the compatibility compiler's own C prototypes.
    extra_cflags="$extra_cflags -D_FORTIFY_SOURCE=0 -include stdio.h"
fi
echo "Building Vox with: $* -cflags $extra_cflags"
# Root browser features are split across main.v and companion module files.
cd "$repo_dir"
if [ -n "$extra_ldflags" ]; then
    "$v_compiler" "$@" \
        -cflags "$extra_cflags" -ldflags "$extra_ldflags" \
        -o "$binary_dir/Vox" .
else
    "$v_compiler" "$@" \
        -cflags "$extra_cflags" \
        -o "$binary_dir/Vox" .
fi

if [ -n "$bridge_library" ]; then
    bridge_resource_tmp=$(mktemp "$binary_dir/.skia-bridge.XXXXXX")
    cp "$bridge_library" "$bridge_resource_tmp"
    chmod 755 "$bridge_resource_tmp"
    mv -f "$bridge_resource_tmp" "$binary_dir/libLadybirdVSkiaText.dylib"
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$binary_dir/libLadybirdVSkiaText.dylib" >/dev/null
    fi
else
    rm -f "$binary_dir/libLadybirdVSkiaText.dylib"
fi

if [ -n "$graphite_library" ]; then
    graphite_resource_tmp=$(mktemp "$binary_dir/.graphite-bridge.XXXXXX")
    cp "$graphite_library" "$graphite_resource_tmp"
    chmod 755 "$graphite_resource_tmp"
    mv -f "$graphite_resource_tmp" "$binary_dir/libVoxGraphite.dylib"
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$binary_dir/libVoxGraphite.dylib" >/dev/null
    fi
else
    rm -f "$binary_dir/libVoxGraphite.dylib"
fi

if [ -n "$dawn_library" ]; then
    dawn_resource_tmp=$(mktemp "$binary_dir/.dawn-bridge.XXXXXX")
    cp "$dawn_library" "$dawn_resource_tmp"
    chmod 755 "$dawn_resource_tmp"
    mv -f "$dawn_resource_tmp" "$binary_dir/libVoxGraphiteDawn.dylib"
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$binary_dir/libVoxGraphiteDawn.dylib" >/dev/null
    fi
else
    rm -f "$binary_dir/libVoxGraphiteDawn.dylib"
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$bundle_dir" >/dev/null
fi

echo "Built production Vox app: $bundle_dir"
echo "Run: open '$bundle_dir'"
