#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${WINDOW_STATE_TEST_OUTPUT_DIR:-"$repo_dir/Build/window-state-test"}
mkdir -p "$output_dir"
profile_dir=$(mktemp -d "$output_dir/profile.XXXXXX")
trap 'rm -rf "$profile_dir"' EXIT HUP INT TERM
clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-deprecated-declarations -framework Cocoa \
    "$repo_dir/tools/native_browser_window_state_test.m" -o "$output_dir/window-state-test"
"$output_dir/window-state-test" "$profile_dir/window-state.plist"
# V state, malformed saves, placement, fullscreen, and detach decisions.
exec env VOX_CHROME_TEST_FILE=main_browser_window_state_test.v sh "$repo_dir/tools/test_address_bar.sh" "$@"
