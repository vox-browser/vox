#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
v_compiler=${V_BIN:-$(command -v v || printf '%s' "$HOME/code/v/v")}
# Native snapshot, notification lifetime and plist conversion.
(cd "$repo_dir" && "$v_compiler" -memory-limit 10G test browserwindow/window_state_darwin_test.v)
# V state, malformed saves, placement, fullscreen, and detach decisions.
exec env VOX_CHROME_TEST_FILE=browserapp/browser_window_state_test.v sh "$repo_dir/tools/test_address_bar.sh" "$@"
