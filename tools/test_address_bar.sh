#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
v_compiler=${V_BIN:-$(command -v v || printf '%s' "$HOME/code/v/v")}
ui2_modules=$(python3 "$repo_dir/tools/prepare_ui2.py" "$v_compiler")
http_modules=$(python3 "$repo_dir/tools/prepare_http_compat.py" "$v_compiler")
test_dir="$repo_dir/Build/v/address-bar-tests"
test_file=${VOX_CHROME_TEST_FILE:-main_address_bar_test.v}
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
# The settings component only needs the native embedding adapter. Keep its
# focused check independent of the complete document/layout engine.
if [ "$test_file" = main_browser_settings_test.v ]; then
    test_dir="$repo_dir/Build/v/settings-tests"
    mkdir -p "$test_dir"
    for name in main_browser_settings.v main_browser_settings_darwin.v; do
        ln -sf "$repo_dir/$name" "$test_dir/$name"
    done
    export VOX_SETTINGS_SCREENSHOT=${VOX_SETTINGS_SCREENSHOT:-"$test_dir/window.png"}
else
    # V puts a test package's parent ahead of -path. Run from Build so an adjacent
    # ~/code/ui2 checkout cannot shadow the staged module and embedding adapter.
    for source in "$repo_dir"/*.v; do
        case "$source" in *_test.v) continue ;; esac
        ln -sf "$source" "$test_dir/$(basename "$source")"
    done
fi
ln -sf "$repo_dir/$test_file" "$test_dir/$test_file"
"$v_compiler" -exclude @vlib/time/zoneinfo.native.v -enable-globals \
    -d vox_ui2 -path "$ui2_modules|$repo_dir|$http_modules|@vmodules|@vlib" \
    -cflags "-DLARGE_CONFIG=1 -O0 -I$repo_dir" "$@" "$test_dir/$test_file"
