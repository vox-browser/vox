#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
v_compiler=${V_BIN:-$(command -v v || printf '%s' "$HOME/code/v/v")}
ui2_modules=$(python3 "$repo_dir/tools/prepare_ui2.py" "$v_compiler")
test_dir="$repo_dir/Build/v/address-bar-tests"
test_file=${VOX_CHROME_TEST_FILE:-main_address_bar_test.v}
mkdir -p "$test_dir"
# V puts a test package's parent ahead of -path. Run from Build so an adjacent
# ~/code/ui2 checkout cannot shadow the staged module and embedding adapter.
for source in "$repo_dir"/*.v; do
    case "$source" in *_test.v) continue ;; esac
    ln -sf "$source" "$test_dir/$(basename "$source")"
done
ln -sf "$repo_dir/$test_file" "$test_dir/$test_file"
"$v_compiler" -exclude @vlib/time/zoneinfo.native.v -enable-globals \
    -d vox_ui2 -path "$ui2_modules|$repo_dir|@vmodules|@vlib" \
    -cflags "-DLARGE_CONFIG=1 -O0 -I$repo_dir" "$@" "$test_dir/$test_file"
