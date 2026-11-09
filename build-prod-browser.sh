#!/bin/sh
set -eu

# Build the optimized V-native browser for the current desktop platform.
#
# usage: build-prod-browser.sh [--no-parallel-cc | --parallel-cc] [--prod]
#
# v.mod selects the V backend. With the C backend, V splits C into units,
# compiles them concurrently
# (-parallel-cc) and links them with ThinLTO, which keeps cross-unit inlining.
# --no-parallel-cc compiles one sealed C unit instead: several times slower to
# build, for maximum binary performance and comparisons with single-unit builds.
# --prod selects V's literal -prod mode without custom C tuning. It defaults
# to one C unit; --parallel-cc selects V's literal -prod -parallel-cc defaults.
#
# Environment overrides:
#   V_BIN                     V compiler executable
#   VOX_USE_SKIA=1             build the explicit legacy renderer (default: GG adapters)
#   UI2_SOURCE_DIR            UI2 checkout (defaults to ~/.vmodules/ui2)
#   LADYBIRD_V_GC            default: prealloc on macOS, boehm on Linux
#                            accepts boehm, boehm_full, prealloc, or none
#   LADYBIRD_V_PROFILE       V profiling report path (unset for normal builds)
#   LADYBIRD_V_PROFILE_FNS   comma-separated C function names to profile
#   LADYBIRD_SOURCE_DIR       upstream Ladybird checkout used for Skia
#   LADYBIRD_VCPKG_TRIPLET    upstream vcpkg triplet directory
#   VOX_BUILD_SCRATCH_DIR     compiler output root (defaults to Build/v)
#   VOX_BUILD_C_MODE          parallel (default) or single; set by the build supervisor
#   VOX_V8=1                  experimental: compile with -d vox_v8, which implements the
#                             JavaScriptCore C API on V8 (see docs/V8_ENGINE.md)
#   VOX_V8_ROOT               V8 headers/library prefix (default: Homebrew node's libnode)

single_c_unit_flag=
v_prod=${VOX_BUILD_V_PROD:-0}
v_prod_flag=
seen_single_option=0
parallel_c_unit_flag=
for argument in "$@"; do
    case "$argument" in
    --no-parallel-cc)
        if [ "$seen_single_option" = 1 ]; then
            echo "usage: build-prod-browser.sh [--no-parallel-cc | --parallel-cc] [--prod]" >&2; exit 2
        fi
        seen_single_option=1; single_c_unit_flag=--no-parallel-cc ;;
    --parallel-cc)
        if [ "$seen_single_option" = 1 ]; then
            echo "usage: build-prod-browser.sh [--no-parallel-cc | --parallel-cc] [--prod]" >&2; exit 2
        fi
        seen_single_option=1; parallel_c_unit_flag=--parallel-cc ;;
    --prod)
        if [ -n "$v_prod_flag" ]; then
            echo "usage: build-prod-browser.sh [--no-parallel-cc | --parallel-cc] [--prod]" >&2; exit 2
        fi
        v_prod=1; v_prod_flag=--prod ;;
    *)
        echo "usage: build-prod-browser.sh [--no-parallel-cc | --parallel-cc] [--prod]" >&2
        exit 2
        ;;
    esac
done
if [ -n "$v_prod_flag" ] && [ "$seen_single_option" = 0 ]; then single_c_unit_flag=--no-parallel-cc; fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
if [ "${VOX_BUILD_SUPERVISED:-0}" != 1 ]; then
    exec python3 "$repo_dir/tools/rebuild_browser.py" --build $single_c_unit_flag $parallel_c_unit_flag $v_prod_flag
fi

case "$(uname -s)" in
    Linux) exec sh "$(dirname -- "$0")/build-linux-browser.sh" "$@" ;;
    Darwin) ;;
    *) echo "Vox supports macOS and Linux" >&2; exit 1 ;;
esac
# Target the app's declared minimum macOS; otherwise clang stamps the host OS
# as the minimum version. Export it before any native helper is compiled: the
# bundled Skia text and AVIF bridges are built ahead of the browser, and a
# build worker that is already running does not see the deploy environment.
MACOSX_DEPLOYMENT_TARGET=$(plutil -extract LSMinimumSystemVersion raw -o - "$repo_dir/packaging/Info.plist")
export MACOSX_DEPLOYMENT_TARGET

# A worker already running when the build protocol changes must finish its
# current job, then hand off before starting another compiler. The successor
# uses the same queued request and guard; no process is interrupted.
if [ "${VOX_BUILD_COMPILE_PROTOCOL:-}" != bundle-lease-v8 ]; then
    python3 "$repo_dir/tools/rebuild_browser.py" --upgrade-worker
    exit 75
fi
: "${VOX_BUILD_RECEIPT_DIR:?production build receipt directory is required}"
python3 "$repo_dir/tools/production_source_manifest.py" begin --root "$repo_dir" \
    --inventory "$VOX_BUILD_RECEIPT_DIR/source-inventory.json"

c_mode=${VOX_BUILD_C_MODE:-parallel}
if [ -n "$single_c_unit_flag" ]; then
    c_mode=single
fi
if [ -n "$parallel_c_unit_flag" ]; then c_mode=parallel; fi
case "$c_mode" in
    parallel|single) ;;
    *)
        echo "VOX_BUILD_C_MODE must be parallel or single" >&2
        exit 2
        ;;
esac

build_dir=${VOX_BUILD_OUTPUT_DIR:-"$repo_dir/Build/v"}
cache_dir="$repo_dir/Build/v"
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

# GG is the production default. Keep the shared parallel compiler intact while
# older installations can use the existing GG-capable compiler. An explicit
# V_BIN is authoritative: fail if it cannot compile the requested renderer.
explicit_v_flag=
if [ -n "${V_BIN:-}" ]; then explicit_v_flag=--explicit; fi
v_compiler=$(python3 "$repo_dir/tools/renderer_build.py" "$v_compiler" \
    --skia "${VOX_USE_SKIA:-0}" $explicit_v_flag --fallback "$HOME/code/v-gg/v")

# The browser owns temporary and retained allocations through scoped arenas.
# Keep the default on that ownership path; collector modes are explicit
# diagnostic overrides.
gc_mode=${LADYBIRD_V_GC:-prealloc}
case "$gc_mode" in
    boehm|boehm_full|prealloc|none) ;;
    *)
        echo "LADYBIRD_V_GC must be boehm, boehm_full, prealloc, or none" >&2
        exit 2
        ;;
esac

case "$(uname -m)" in
    arm64|aarch64) default_vcpkg_triplet=arm64-osx-dynamic ;;
    x86_64|amd64) default_vcpkg_triplet=x64-osx-dynamic ;;
    *)
        echo "Unsupported macOS architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

mkdir -p "$binary_dir" "$resources_dir"
# Failed compiler jobs can leave Mach-O/object scratch directories beside their
# output. Keep those outside the app so they cannot invalidate bundle signing.
compiler_output_root=${VOX_BUILD_SCRATCH_DIR:-$build_dir}
mkdir -p "$compiler_output_root"
compile_dir=$(mktemp -d "$compiler_output_root/compiler-output.XXXXXX")
# Failed builds exit through set -e; remove their scratch as well.
trap 'rm -rf "$compile_dir"' EXIT
echo "Compiler outputs: $compile_dir"
cp "$repo_dir/packaging/Info.plist" "$bundle_dir/Contents/Info.plist"
cp "$repo_dir/packaging/Vox.icns" "$resources_dir/Vox.icns"
# Keep the codec and metadata beside the binary snapshot. Non--prod V embeds
# otherwise reopen checkout files, which may change after this bundle is built.
for adblock_asset in engine.snapshot.bin engine.snapshot.json.gz engine.js.gz; do
    adblock_resource="adblock.$adblock_asset"
    if [ "$adblock_asset" = engine.snapshot.bin ]; then
        adblock_resource=adblock.snapshot.bin
    fi
    if ! cmp -s "$repo_dir/adblock/$adblock_asset" "$resources_dir/$adblock_resource"; then
        adblock_resource_tmp=$(mktemp "$resources_dir/.adblock-resource.XXXXXX")
        cp "$repo_dir/adblock/$adblock_asset" "$adblock_resource_tmp"
        chmod 644 "$adblock_resource_tmp"
        mv -f "$adblock_resource_tmp" "$resources_dir/$adblock_resource"
    fi
done

extra_cflags=""
if [ "$gc_mode" = boehm ] || [ "$gc_mode" = boehm_full ]; then
    # The compatibility compiler's source-built collector has only 2048
    # static-root ranges. AppKit/Metal's dyld images exceed that limit; match
    # the large configuration used by current V and its macOS GC archives.
    extra_cflags="-DLARGE_CONFIG=1"
fi
# Mach-O keeps referenced entry points and initializers. Drop unreachable native
# backends and their unreferenced dylibs from the production executable.
extra_ldflags="-Wl,-dead_strip,-dead_strip_dylibs"
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
# A fresh Cargo build fails to load its proc-macro crates (rustc reports
# "can't find crate for thiserror_impl") whenever MACOSX_DEPLOYMENT_TARGET is
# set. Build the JPEG XL helper without it; it keeps rustc's lower default
# minimum, which the release accepts.
# The browser exports the planar converter from media/yuv_bridge.v. Its pure V
# implementation preserves the previous decoder's integer color quantization.
extra_cflags="$extra_cflags -DLADYBIRD_V_HAS_V_YUV"
jpegxl_library=""
if [ -n "$rust_cargo" ]; then
    jpegxl_target_dir="$cache_dir/rust-jpegxl"
    env -u MACOSX_DEPLOYMENT_TARGET PATH="$(dirname "$rust_cargo"):$PATH" CARGO_TARGET_DIR="$jpegxl_target_dir" \
        "$rust_cargo" build --quiet --release --locked \
        --manifest-path "$repo_dir/native_jpegxl_rust/Cargo.toml"
    jpegxl_library="$build_dir/libVoxJPEGXL.dylib"
    cp "$jpegxl_target_dir/release/libvox_jpegxl.dylib" "$jpegxl_library"
    install_name_tool -id @rpath/libVoxJPEGXL.dylib "$jpegxl_library"
fi
avif_library=""
if [ -f "$skia_root/lib/libavif.dylib" ] && [ -f "$skia_root/include/avif/avif.h" ]; then
    avif_library="$build_dir/libVoxAVIF.dylib"
    python3 "$repo_dir/tools/build_native_avif.py" --sdk-root "$skia_root" --output "$avif_library"
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
    snapshot_deflate=$(python3 "$repo_dir/tools/build_snapshot_deflate.py")
    cp "$snapshot_deflate/libdeflate-1.24/COPYING" "$resources_dir/libdeflate-LICENSE.txt"
    clang++ -std=c++20 -O3 -fno-rtti -fPIC -dynamiclib -x objective-c++ \
		-I"$skia_root/include/skia" -I"$skia_root/include" \
		-DLADYBIRD_V_HAS_SNAPSHOT_DEFLATE -I"$snapshot_deflate/libdeflate-1.24" \
		"$repo_dir/native_skia_text_darwin.cpp" \
        -x none "$snapshot_deflate/snapshot-build/libdeflate.a" \
        "-Wl,-unexported_symbol,_libdeflate_*" \
        -L"$skia_root/lib" -lskia \
        -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework Foundation -framework Metal -framework IOSurface \
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
    # Other modules also add Homebrew ICU search paths. Use the exact library
    # so their earlier -L flags cannot select a different ICU major version.
    # Codec entry points load on first use through native/include/native_ffmpeg_darwin.h.
    extra_ldflags="$extra_ldflags $skia_root/lib/libicuuc.dylib -Wl,-rpath,$skia_root/lib"
fi

# `-d vox_v8` (VOX_V8=1) is an experimental compile-time backend: the
# JavaScriptCore C API that every binding uses, implemented on V8
# (browserjs/v8/jsc_on_v8.cpp). Its V8 headers need C++20, which V's helper
# objects do not use, so build it as a library here. Homebrew's node exports
# V8's API from libnode; VOX_V8_ROOT selects another prefix.
v8_library=
if [ "${VOX_V8:-0}" = 1 ]; then
    v8_root=${VOX_V8_ROOT:-/opt/homebrew}
    v8_runtime=
    for candidate in "$v8_root"/lib/libnode.*.dylib; do
        if [ -f "$candidate" ]; then v8_runtime=$candidate; fi
    done
    if [ -z "$v8_runtime" ] || [ ! -f "$v8_root/include/node/v8.h" ]; then
        echo "VOX_V8=1 needs V8 headers and libnode under $v8_root (brew install node)" >&2
        exit 2
    fi
    v8_library="$build_dir/libVoxJSCOnV8.dylib"
    clang++ -std=c++20 -O3 -fPIC -dynamiclib -fvisibility=hidden \
        -I"$v8_root/include/node" -I"$repo_dir/browserjs/v8/include" \
        "$repo_dir/browserjs/v8/jsc_on_v8.cpp" "$v8_runtime" \
        -framework CoreFoundation -Wl,-rpath,"$v8_root/lib" \
        -Wl,-install_name,@rpath/libVoxJSCOnV8.dylib -o "$v8_library"
    extra_ldflags="$extra_ldflags -L$build_dir -lVoxJSCOnV8 -Wl,-rpath,@executable_path"
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
prealloc_modules=""
# Every collector uses glyph-index lookup in the platform font bridge. Avoid
# decoding x.ttf's dense Unicode vectors only to discard them after each face
# initialization. Stage the same checked initializer for every browser build.
font_modules=$(python3 "$repo_dir/tools/prepare_font_runtime.py" "$v_compiler")
if [ "$gc_mode" = prealloc ]; then
    prealloc_modules=$(python3 "$repo_dir/tools/prepare_prealloc_runtime.py" "$v_compiler" "$cache_dir/prealloc-runtime")
    v_compiler="$prealloc_modules/compiler/v"
fi
# Anchor package names at the repository; see build-linux-browser.sh. Without
# it, a checkout under `modules`, `.vmodules`, `vlib` or another v.mod compiles
# `encoding` as `vox2.encoding` while imports still resolve to vlib's name.
# Pin the manifest's frontend and Clang for native code and C optimization.
# V drivers without manifest defaults need the backend passed explicitly.
v_backend=${VOX_BUILD_BACKEND:-$(python3 "$repo_dir/tools/browser_backend.py" "$repo_dir")}
case "$v_backend" in c|fastc) ;; *) echo "Unsupported browser backend: $v_backend" >&2; exit 2 ;; esac
set -- -b "$v_backend" -cc clang -memory-limit 10G -exclude "$zoneinfo_exclude" -enable-globals -d vox_sparse_ttf \
    -d vox_production -d vox_ui2 -path "$repo_dir|$prealloc_modules|$font_modules|$http_modules|$ui2_modules|@vmodules|@vlib"
# Verify the staged compiler's actual library too. Legacy builds are explicit;
# unsupported default compilers must not silently produce a Skia-default app.
python3 "$repo_dir/tools/renderer_build.py" "$v_compiler" --explicit \
    --skia "${VOX_USE_SKIA:-0}" --receipt "$VOX_BUILD_RECEIPT_DIR/renderer.json" >/dev/null
if [ "${VOX_USE_SKIA:-0}" != 1 ]; then
    set -- "$@" -d vox_gg_canvas
fi
if [ "${VOX_KEEP_C:-0}" = 1 ]; then
    set -- "$@" -keepc
fi
if [ -n "$v8_library" ]; then
    set -- "$@" -d vox_v8
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
    # Avoid retaining the imported-module cache graph and declaration-notice
    # analysis alongside the complete prealloc browser under the 10 GiB budget.
    set -- "$@" -w -n -nocache -prealloc -gc none
    # Optimize the generated engine translation unit without changing V's
    # runtime checks or floating-point semantics. Matched CNN controls retain
    # the same native inputs; -O3 removes additional layout/cascade overhead.
    # The generated translation unit contains many small style/layout adapters.
    # Inline across those adapters without relaxing checks or FP semantics.
    if [ "$v_prod" != 1 ]; then
        extra_cflags="$extra_cflags -O3 -mllvm -inline-threshold=1500"
        # ThinLTO inlines across split C units at link time; keep the same threshold.
        parallel_lto_ldflags=" -Wl,-mllvm,-inline-threshold=1500"
    fi
elif [ "$gc_mode" != none ]; then
    set -- "$@" -gc "$gc_mode"
    if [ "$(uname -m)" = arm64 ] && [ "$(getconf PAGESIZE)" = 16384 ]; then
        # Apple Silicon can return only whole 16 KiB pages to the OS. A
        # prebuilt collector's 4 KiB blocks strand free space beside live
        # blocks in the same page. Use V's source-built collector with one
        # allocation block per native page; keep its normal ownership rules.
        set -- "$@" -d use_bundled_libgc
        extra_cflags="$extra_cflags -DHBLKSIZE=16384"
    fi
    extra_cflags="$extra_cflags -O2"
else
    set -- "$@" -prod -gc none
fi
if [ "$v_prod" = 1 ]; then set -- "$@" -prod; fi
requested_c_mode=$c_mode
if [ -n "${LADYBIRD_V_PROFILE:-}" ]; then
    # V compiles profiled programs as one unit inside the resident compiler.
    c_mode=single
    set -- "$@" -profile "$LADYBIRD_V_PROFILE" -profile-no-inline \
        -profile-fns "${LADYBIRD_V_PROFILE_FNS:-main__BrowserApp_install_loaded_page,layout__run_document_layout_with_renderer_mode}"
    # V emits profiling stdio calls ahead of the macOS stdio declarations.
    # Include those declarations first, without fortified function-like macros
    # that would rewrite the compatibility compiler's own C prototypes.
    extra_cflags="$extra_cflags -D_FORTIFY_SOURCE=0 -include stdio.h"
fi
# Finish all source-consuming helper work before sealing browser C inputs.
(
if [ "$gc_mode" = prealloc ]; then
    cd "$prealloc_modules/compiler"
fi
# Keep the filter worker's entry point independent of browser/UI initialization.
# It uses the same engine, snapshot resource and private transport as self-exec.
helper_tmp="$compile_dir/VoxAdblockWorker"
set -- -b "$v_backend" -cc clang -memory-limit 10G -exclude "$zoneinfo_exclude" -enable-globals -d vox_sparse_ttf -d vox_filter_worker_minimal_links \
    -path "$repo_dir|$prealloc_modules|$font_modules|$http_modules|@vmodules|@vlib"
helper_cflags=-O2
if [ "$gc_mode" = prealloc ]; then
    set -- "$@" -w -n -nocache -prealloc -gc none
    if [ "$v_prod" = 1 ]; then helper_cflags=; fi
elif [ "$gc_mode" != none ]; then
    set -- "$@" -gc "$gc_mode"
    helper_cflags="$helper_cflags -DLARGE_CONFIG=1"
    if [ "$(uname -m)" = arm64 ] && [ "$(getconf PAGESIZE)" = 16384 ]; then
        set -- "$@" -d use_bundled_libgc
        helper_cflags="$helper_cflags -DHBLKSIZE=16384"
    fi
else
    set -- "$@" -prod -gc none
fi
if [ "$v_prod" = 1 ]; then set -- "$@" -prod; fi
# Imported font/runtime modules may contribute link flags without any live
# helper symbols. Do not initialize their unused native libraries at startup.
export V_MACOS_V3_SOURCE_MANIFEST=1
export V_MACOS_V3_C_ERROR_DIR="$VOX_BUILD_RECEIPT_DIR/worker-sources"
# Compile the module directory so FastC enables full language support, including
# the generic JSON transport. Its single-file mode uses a restricted parser.
python3 "$repo_dir/tools/production_source_manifest.py" compile --root "$repo_dir" \
    --inventory "$VOX_BUILD_RECEIPT_DIR/source-inventory.json" \
    --component-dir "$VOX_BUILD_RECEIPT_DIR/worker-sources" \
    --command "$v_compiler" "$@" -cflags "$helper_cflags" -ldflags "-Wl,-dead_strip,-dead_strip_dylibs" \
    -o "$helper_tmp" "$repo_dir/tools/adblock-worker-mini"
chmod 755 "$helper_tmp"
if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - --entitlements "$repo_dir/packaging/Vox.entitlements.plist" "$helper_tmp" >/dev/null
fi
mv -f "$helper_tmp" "$binary_dir/VoxAdblockWorker"

)

echo "Building Vox ($c_mode C) with: $* -cflags $extra_cflags"
# Root browser features are split across main.v and companion module files.
if [ "$gc_mode" = prealloc ]; then
    # V resolves builtin from its compiler root rather than -path. The staged
    # executable/library view selects our bounded allocator without editing V.
    cd "$prealloc_modules/compiler"
else
    cd "$repo_dir"
fi
if [ "$v_backend" = fastc ]; then
    # FastC compiles its own C units and does not support -dump-c-flags or
    # parsed-buffer manifests. The supervisor retains its whole-input identity
    # check before publication; there is no fallback to the C frontend.
    v_prod_json=false
    if [ "$v_prod" = 1 ]; then v_prod_json=true; fi
    printf '{"backend": "fastc", "mode": "fastc", "requested": "%s", "v_prod": %s}\n' \
        "$requested_c_mode" "$v_prod_json" > "$VOX_BUILD_RECEIPT_DIR/c-compile.json"
    python3 "$repo_dir/tools/production_source_manifest.py" compile --root "$repo_dir" \
        --inventory "$VOX_BUILD_RECEIPT_DIR/source-inventory.json" \
        --component-dir "$VOX_BUILD_RECEIPT_DIR/browser-sources" --command "$v_compiler" "$@" \
        -cflags "$extra_cflags" -ldflags "$extra_ldflags" -o "$compile_dir/Vox" "$repo_dir"
elif [ "$c_mode" = parallel ]; then
    # V compiles the split units itself and links them. Without native-header
    # split support, or when native code would be duplicated in every unit, the
    # helper leaves no executable and the sealed single-unit compile below runs.
    if [ "$v_prod" = 1 ]; then
        python3 "$repo_dir/tools/parallel_browser_compile.py" --receipt "$VOX_BUILD_RECEIPT_DIR" \
            --output "$compile_dir/Vox" -- "$v_compiler" "$@" \
            -cflags "$extra_cflags" -ldflags "$extra_ldflags" "$repo_dir"
    else
        python3 "$repo_dir/tools/parallel_browser_compile.py" --receipt "$VOX_BUILD_RECEIPT_DIR" \
            --output "$compile_dir/Vox" -- "$v_compiler" "$@" \
            -cflags "$extra_cflags -flto=thin" \
            -ldflags "$extra_ldflags -flto=thin${parallel_lto_ldflags:-}" "$repo_dir"
    fi
else
    v_prod_json=false
    if [ "$v_prod" = 1 ]; then v_prod_json=true; fi
    printf '{"mode": "single", "requested": "%s", "v_prod": %s}\n' "$requested_c_mode" "$v_prod_json" > "$VOX_BUILD_RECEIPT_DIR/c-compile.json"
fi
if [ ! -f "$compile_dir/Vox" ]; then
    generated_dir="$VOX_BUILD_RECEIPT_DIR/generated"
    mkdir -p "$generated_dir"
    export V_MACOS_V3_SOURCE_MANIFEST=1
    export V_MACOS_V3_C_ERROR_DIR="$VOX_BUILD_RECEIPT_DIR/browser-sources"
    compile_browser_v() {
        python3 "$repo_dir/tools/production_source_manifest.py" compile --root "$repo_dir" \
            --inventory "$VOX_BUILD_RECEIPT_DIR/source-inventory.json" \
            --component-dir "$VOX_BUILD_RECEIPT_DIR/browser-sources" --command "$v_compiler" "$@"
    }
    if [ -n "$extra_ldflags" ]; then
        compile_browser_v "$@" \
            -cflags "$extra_cflags" -ldflags "$extra_ldflags" \
            -dump-c-flags "$generated_dir/Vox.flags" -o "$generated_dir/Vox.c" "$repo_dir"
    else
        compile_browser_v "$@" \
            -cflags "$extra_cflags" \
            -dump-c-flags "$generated_dir/Vox.flags" -o "$generated_dir/Vox.c" "$repo_dir"
    fi
    set -- --root "$repo_dir" --stage "$build_dir" --receipt "$VOX_BUILD_RECEIPT_DIR" \
        --source "$generated_dir/Vox.c" --flags "$generated_dir/Vox.flags" --output "$compile_dir/Vox"
    if [ -f "$VOX_BUILD_RECEIPT_DIR/worker-sources/v_sources" ] || \
       [ -f "$VOX_BUILD_RECEIPT_DIR/browser-sources/v_sources" ]; then
        # A compiler without manifest support retains the whole-tree check.
        # Partial manifests fail in combine rather than weakening verification.
        python3 "$repo_dir/tools/production_source_manifest.py" combine --parsed --root "$repo_dir" \
            --inventory "$VOX_BUILD_RECEIPT_DIR/source-inventory.json" \
            --component "$VOX_BUILD_RECEIPT_DIR/worker-sources" \
            --component "$VOX_BUILD_RECEIPT_DIR/browser-sources" \
            --output "$VOX_BUILD_RECEIPT_DIR/source-manifest.json"
        set -- "$@" --source-manifest "$VOX_BUILD_RECEIPT_DIR/source-manifest.json" \
            --source-inventory "$VOX_BUILD_RECEIPT_DIR/source-inventory.json" \
            --parsed-component "$VOX_BUILD_RECEIPT_DIR/worker-sources" \
            --parsed-component "$VOX_BUILD_RECEIPT_DIR/browser-sources"
    fi
    python3 "$repo_dir/tools/freeze_browser_compile.py" "$@"
fi
mv -f "$compile_dir/Vox" "$binary_dir/Vox"
python3 "$repo_dir/tools/localize_bundle_rpaths.py" "$binary_dir/Vox" "$build_dir"


if [ -n "${jpegxl_library:-}" ]; then
    jpegxl_resource_tmp=$(mktemp "$binary_dir/.jpegxl.XXXXXX")
    cp "$jpegxl_library" "$jpegxl_resource_tmp"
    chmod 755 "$jpegxl_resource_tmp"
    mv -f "$jpegxl_resource_tmp" "$binary_dir/libVoxJPEGXL.dylib"
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$binary_dir/libVoxJPEGXL.dylib" >/dev/null
    fi
else
    rm -f "$binary_dir/libVoxJPEGXL.dylib"
fi

if [ -n "$avif_library" ]; then
    avif_resource_tmp=$(mktemp "$binary_dir/.avif.XXXXXX")
    cp "$avif_library" "$avif_resource_tmp"
    chmod 755 "$avif_resource_tmp"
    mv -f "$avif_resource_tmp" "$binary_dir/libVoxAVIF.dylib"
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$binary_dir/libVoxAVIF.dylib" >/dev/null
    fi
else
    rm -f "$binary_dir/libVoxAVIF.dylib"
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

if [ -n "$v8_library" ]; then
    v8_resource_tmp=$(mktemp "$binary_dir/.v8-backend.XXXXXX")
    cp "$v8_library" "$v8_resource_tmp"
    chmod 755 "$v8_resource_tmp"
    mv -f "$v8_resource_tmp" "$binary_dir/libVoxJSCOnV8.dylib"
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$binary_dir/libVoxJSCOnV8.dylib" >/dev/null
    fi
else
    rm -f "$binary_dir/libVoxJSCOnV8.dylib"
fi

if command -v codesign >/dev/null 2>&1; then
    # Current macOS JavaScriptCore requires this entitlement for its JIT,
    # including when the embedding app is ad-hoc signed.
    codesign --force --sign - --entitlements "$repo_dir/packaging/Vox.entitlements.plist" "$bundle_dir" >/dev/null
fi
rm -rf "$compile_dir"

echo "Built production Vox app: $bundle_dir"
echo "Run: open '$bundle_dir'"
