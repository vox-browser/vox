#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
v_compiler=${V_BIN:-$(command -v v || printf '%s' "$HOME/code/v/v")}
ui2_modules=$(python3 "$repo_dir/tools/prepare_ui2.py" "$v_compiler" --lease-pid "$$")
http_modules=$(python3 "$repo_dir/tools/prepare_http_compat.py" "$v_compiler")
test_dir="$repo_dir/Build/v/address-bar-tests"
test_file=${VOX_CHROME_TEST_FILE:-browserapp/address_bar_test.v}
test_name=$(basename "$test_file")
mkdir -p "$test_dir"
# Sources stay in the canonical checkout. Remove retired links, and expose the
# headers and module directories used by includes in this test package.
for source in "$test_dir"/*.v; do
    if [ -L "$source" ] && [ ! -e "$source" ]; then rm "$source"; fi
done
for header in "$repo_dir"/*.h; do
    ln -sf "$header" "$test_dir/$(basename "$header")"
done
for directory in "$repo_dir"/*; do
    [ -d "$directory" ] || continue
    [ "$(basename "$directory")" != Build ] || continue
    ln -sfn "$directory" "$test_dir/$(basename "$directory")"
done
# Resolve implementation sources through links to the canonical checkout.
# v.mod's `subdirs` add the linked source directories to this module.
ln -sf "$repo_dir/v.mod" "$test_dir/v.mod"
for source in "$repo_dir"/*.v; do
    case "$source" in *_test.v) continue ;; esac
    ln -sf "$source" "$test_dir/$(basename "$source")"
done
ln -sf "$repo_dir/$test_file" "$test_dir/$test_name"
"$v_compiler" -exclude @vlib/time/zoneinfo.native.v -enable-globals \
    -d vox_ui2 -path "$ui2_modules|$repo_dir|$http_modules|@vmodules|@vlib" \
    -cflags "-DLARGE_CONFIG=1 -O0 -I$repo_dir" "$@" "$test_dir/$test_name"
