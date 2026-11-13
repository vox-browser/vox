#!/bin/sh
set -eu

if [ "$(uname -s)" != Linux ]; then
    echo "build-linux-browser.sh must run on Linux" >&2
    exit 1
fi
if [ "$#" -ne 0 ]; then
    echo "usage: build-linux-browser.sh" >&2
    exit 2
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
# V owns the build helpers; the shell only bootstraps compiler discovery.
v_tool() { sh "$repo_dir/tools/run_v_tool.sh" "$@"; }
# Match the supervisor's protocol; stale workers hand off before compiling.
if [ "${VOX_BUILD_SUPERVISED:-0}" = 1 ] && [ "${VOX_BUILD_COMPILE_PROTOCOL:-}" != bundle-lease-v10-vtools ]; then
    v_tool rebuild_browser --upgrade-worker
    exit 75
fi
v_compiler=${V_BIN:-}
if [ -z "$v_compiler" ]; then
    v_compiler=$(command -v v || true)
    v_compiler=${v_compiler:-"$HOME/code/v/v"}
else
    v_compiler=$(command -v "$v_compiler" || true)
fi
if [ ! -x "$v_compiler" ]; then
    echo "V compiler not found. Set V_BIN to an executable V compiler." >&2
    exit 1
fi
# Resolve the caller's relative path before the supervisor or helpers change directory.
# Keep the executable name intact: a symlink may select a compiler wrapper.
case "$v_compiler" in
    /*) ;;
    *) v_compiler="$(pwd -P)/$v_compiler" ;;
esac
if [ "${VOX_BUILD_SUPERVISED:-0}" != 1 ]; then
    V_BIN=$v_compiler
    export V_BIN
    exec sh "$repo_dir/tools/run_v_tool.sh" rebuild_browser --build
fi
build_dir=${VOX_BUILD_OUTPUT_DIR:-"$repo_dir/Build/linux"}
cache_dir="$repo_dir/Build/linux"
gc_mode=${LADYBIRD_V_GC:-boehm}
case "$gc_mode" in
    boehm|boehm_full|prealloc|none) ;;
    *) echo "LADYBIRD_V_GC must be boehm, boehm_full, prealloc, or none" >&2; exit 2 ;;
esac

# Use the current frontend, matching the macOS production build. The driver's
# historical environment variable also controls fallback on Linux.
V_MACOS_V3_NO_FALLBACK=1
export V_MACOS_V3_NO_FALLBACK
v_backend=${VOX_BUILD_BACKEND:-$(v_tool browser_backend "$repo_dir")}
if [ "$v_backend" = c ]; then
    v_compiler=$(v_tool prepare_v_match_scope "$v_compiler")
fi

export PKG_CONFIG_PATH="$repo_dir/Build/deps/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
for dependency in javascriptcoregtk-4.1 glib-2.0 fontconfig freetype2 harfbuzz egl glesv2; do
    if ! pkg-config --exists "$dependency"; then
        echo "Missing dependency: $dependency. See docs/LINUX.md." >&2
        exit 1
    fi
done
mkdir -p "$build_dir"
# JPEG XL is decoded by the V jpegxl module; drop the former Rust helper.
rm -f "$build_dir/libVoxJPEGXL.so"
if pkg-config --exists libavif; then
    v_tool build_native_avif --output "$build_dir/libVoxAVIF.so"
else
    rm -f "$build_dir/libVoxAVIF.so"
fi
v_tool build_linux_native
http_modules=$(v_tool prepare_http_compat "$v_compiler")
ui2_modules=$(sh "$repo_dir/tools/run_v_tool.sh" prepare_ui2 "$v_compiler")
linux_modules=$(v_tool prepare_linux_modules "$v_compiler")
module_paths="$repo_dir|$ui2_modules|$linux_modules|$http_modules|@vmodules|@vlib"
if [ "$gc_mode" = prealloc ]; then
    # Use the production bounded realloc and persistent closure metadata;
    # allocator flags alone do not provide those ownership guarantees.
    prealloc_modules=$(v_tool prepare_prealloc_runtime "$v_compiler" "$cache_dir/prealloc-runtime")
    v_compiler="$prealloc_modules/compiler/v"
    module_paths="$repo_dir|$prealloc_modules|$ui2_modules|$linux_modules|$http_modules|@vmodules|@vlib"
fi
# The compiler qualifies packages from the nearest `modules`,
# `.vmodules`, `vlib` or lookup-path-named directory, or from an ancestor v.mod.
# A checkout such as ~/.vmodules/vox2 would compile `encoding` as
# `vox2.encoding` while its imports still name vlib's `encoding` directory.
# Listing the repository first keeps its packages unqualified wherever it lives.
case "$v_backend" in c|fastc) ;; *) echo "Unsupported browser backend: $v_backend" >&2; exit 2 ;; esac
set -- -b "$v_backend" -memory-limit 10G -enable-globals -cc "${CC:-clang}" \
    -d vox_production -d use_openssl \
    -exclude '@vlib/time/zoneinfo.native.v' \
    -path "$module_paths"
if [ "$gc_mode" = prealloc ]; then
    # Match macOS production: -prealloc alone leaves the default collector
    # selected. Keep the compiler's imported graph within its memory budget.
    set -- "$@" -w -n -nocache -prealloc -gc none
elif [ "$gc_mode" = none ]; then
    set -- "$@" -gc none
else
    # Use the distribution's threaded collector, rather than building V's
    # bundled collector through its object-file cache.
    set -- "$@" -gc "$gc_mode" -d dynamic_boehm
fi
if [ "$gc_mode" = none ] || [ "${VOX_BUILD_V_PROD:-0}" = 1 ]; then
    set -- "$@" -prod
fi
if [ "$gc_mode" = prealloc ]; then
    # V resolves builtin relative to its compiler root, not just -path.
    # Compile from the staged view, with the application source made absolute.
    cd "$prealloc_modules/compiler"
    browser_source="$repo_dir"
else
    cd "$repo_dir"
    browser_source=.
fi
echo "Building Vox ($gc_mode) with: $*"
# glibc exposes pthread_setname_np and pthread_getattr_np only with GNU extensions.
"$v_compiler" "$@" -show-c-output -cflags "-D_GNU_SOURCE=1 ${VOX_LINUX_CFLAGS:--O2}" -o "$build_dir/vox" "$browser_source"
echo "Built Vox: $build_dir/vox"
echo "Run: '$build_dir/vox' https://example.com"
