#!/bin/sh
# Bootstrap build tools using only the V compiler and the host shell.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
tool=$1
shift
case "$tool" in *[!a-zA-Z0-9_]*) echo 'Invalid Vox tool name' >&2; exit 2 ;; esac
v_tool_compiler=${V_BIN:-}
if [ -z "$v_tool_compiler" ]; then
    v_tool_compiler=$(command -v v || true)
    v_tool_compiler=${v_tool_compiler:-"$HOME/code/v/v"}
fi
V_MACOS_V3_NO_FALLBACK=1
VFLAGS=
export V_MACOS_V3_NO_FALLBACK VFLAGS
# V frontends may retain their generated C beside the requested output.
# Keep bootstrap output ephemeral and away from the source checkout.
tool_output_dir=$(mktemp -d "${TMPDIR:-/tmp}/vox-build-tool.XXXXXX")
trap 'rm -rf "$tool_output_dir"' EXIT
"$v_tool_compiler" -b c -memory-limit 10G -o "$tool_output_dir/$tool" run "$repo_dir/tools/$tool.vsh" "$@"
