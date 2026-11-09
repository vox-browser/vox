#!/bin/sh
# Bootstrap Vox's build tool using the V compiler already required by Vox.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
compiler=${V_BIN:-}
if [ -z "$compiler" ]; then
    compiler=$(command -v v || true)
    compiler=${compiler:-"$HOME/code/v/v"}
else
    compiler=$(command -v "$compiler" || true)
fi
if [ ! -x "$compiler" ]; then
    echo 'V compiler not found. Set V_BIN to an executable V compiler.' >&2
    exit 1
fi
case "$compiler" in /*) ;; *) compiler="$(pwd -P)/$compiler" ;; esac
# Keep the distinction between an explicit V_BIN and a discovered compiler:
# the renderer may select the documented GG fallback only for the latter.
if [ -n "${V_BIN:-}" ]; then
    V_BIN=$compiler
    export V_BIN
fi
V_MACOS_V3_NO_FALLBACK=1
export V_MACOS_V3_NO_FALLBACK
cache_dir="$repo_dir/Build/tools"
mkdir -p "$cache_dir"
input_identity() {
    {
        printf '%s\n' "$compiler" "${CC:-}" "${VFLAGS:-}"
        cksum "$compiler" "$repo_dir/tools/vox-build.sh"
        find "$repo_dir/tools/voxbuild" -type f -print | LC_ALL=C sort |
            while IFS= read -r source; do cksum "$source"; done
    } | cksum
}
identity=$(input_identity)
cache_key=$(printf '%s' "$identity" | tr ' ' '-')
binary="$cache_dir/vox-build-$cache_key"
if [ ! -x "$binary" ]; then
    temporary=$(mktemp -d "$cache_dir/.bootstrap.XXXXXX")
    trap 'rm -rf "$temporary"' EXIT HUP INT TERM
    # This small bootstrap uses V's compiler limit. The compiled tool applies
    # the aggregate process-tree guard to production and dependency builds.
    case "$(uname -s)" in
        Linux) "$compiler" -b c -memory-limit 10G -gc none -cc "${CC:-clang}" -o "$temporary/vox-build" "$repo_dir/tools/voxbuild" >&2 ;;
        *) "$compiler" -b c -memory-limit 10G -gc none -o "$temporary/vox-build" "$repo_dir/tools/voxbuild" >&2 ;;
    esac
    if [ "$(input_identity)" != "$identity" ]; then
        echo 'Build tool sources changed during compilation; retry the build.' >&2
        exit 1
    fi
    chmod 755 "$temporary/vox-build"
    # Each input identity owns an immutable executable. Concurrent bootstraps
    # can publish the same identity, but never overwrite a running tool or
    # associate a different executable with a separately written cache stamp.
    if ! ln "$temporary/vox-build" "$binary" 2>/dev/null && [ ! -x "$binary" ]; then
        echo "Cannot publish the build tool: $binary" >&2
        exit 1
    fi
    rm -rf "$temporary"
    trap - EXIT HUP INT TERM
fi
# Refresh the convenient path on cache hits too, including a checkout rollback.
# Workers and receipts always pin the immutable executable selected above.
if [ "$(readlink "$cache_dir/vox-build" 2>/dev/null || true)" != "$(basename "$binary")" ]; then
    temporary=$(mktemp -d "$cache_dir/.current.XXXXXX")
    trap 'rm -rf "$temporary"' EXIT HUP INT TERM
    ln -s "$(basename "$binary")" "$temporary/current"
    mv -f "$temporary/current" "$cache_dir/vox-build"
    rm -rf "$temporary"
    trap - EXIT HUP INT TERM
fi
VOX_BUILD_ROOT=$repo_dir
VOX_BUILD_TOOL=$binary
export VOX_BUILD_ROOT VOX_BUILD_TOOL
exec "$binary" "$@"
