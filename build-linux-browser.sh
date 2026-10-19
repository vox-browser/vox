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
build_dir="$repo_dir/Build/linux"
v_compiler=${V_BIN:-}
if [ -z "$v_compiler" ]; then
    v_compiler=$(command -v v || true)
    v_compiler=${v_compiler:-"$HOME/code/v/v"}
fi
if [ ! -x "$v_compiler" ]; then
    echo "V compiler not found. Set V_BIN to an executable V compiler." >&2
    exit 1
fi
gc_mode=${LADYBIRD_V_GC:-boehm}
case "$gc_mode" in
    boehm|boehm_full|none) ;;
    *) echo "LADYBIRD_V_GC must be boehm, boehm_full, or none" >&2; exit 2 ;;
esac

export PKG_CONFIG_PATH="$repo_dir/Build/deps/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
for dependency in javascriptcoregtk-4.1 glib-2.0 fontconfig harfbuzz icu-uc icu-i18n egl glesv2 skia; do
    if ! pkg-config --exists "$dependency"; then
        echo "Missing dependency: $dependency. See docs/LINUX.md." >&2
        exit 1
    fi
done
mkdir -p "$build_dir"
python3 "$repo_dir/tools/build_regex_backend.py"
python3 "$repo_dir/tools/build_linux_native.py"
http_modules=$(python3 "$repo_dir/tools/prepare_http_compat.py" "$v_compiler")
linux_modules=$(python3 "$repo_dir/tools/prepare_linux_modules.py" "$v_compiler")
# The compatibility compiler qualifies packages from the nearest `modules`,
# `.vmodules`, `vlib` or lookup-path-named directory, or from an ancestor v.mod.
# A checkout such as ~/.vmodules/vox2 would compile `encoding` as
# `vox2.encoding` while its imports still name vlib's `encoding` directory.
# Listing the repository first keeps its packages unqualified wherever it lives.
set -- -enable-globals -cc "${CC:-clang}" \
    -d use_openssl \
    -exclude '@vlib/time/zoneinfo.native.v' \
    -path "$repo_dir|$linux_modules|$http_modules|@vmodules|@vlib" -gc "$gc_mode"
if [ "$gc_mode" = none ]; then
    set -- "$@" -prod
else
    # Use the distribution's threaded collector, rather than building V's
    # bundled collector through its object-file cache.
    set -- "$@" -d dynamic_boehm
fi
cd "$repo_dir"
"$v_compiler" "$@" -show-c-output -cflags "${VOX_LINUX_CFLAGS:--O2}" -o "$build_dir/vox" .
echo "Built Vox: $build_dir/vox"
echo "Run: '$build_dir/vox' https://example.com"
