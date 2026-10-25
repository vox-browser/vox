#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${WINDOW_STATE_TEST_OUTPUT_DIR:-"$repo_dir/Build/window-state-test"}
mkdir -p "$output_dir"
profile_dir=$(mktemp -d "$output_dir/profile.XXXXXX")
trap 'rm -rf "$profile_dir"' EXIT HUP INT TERM
clang -Wall -Wextra -Werror -Wno-deprecated-declarations -framework Cocoa \
    "$repo_dir/tools/native_browser_window_state_test.m" -o "$output_dir/window-state-test"
for mode in normal-write normal-read max-write max-read fullscreen-write fullscreen-read; do
    VOX_TEST_WINDOW=1 "$output_dir/window-state-test" "$mode" "$profile_dir/window-state.plist"
done
printf 'invalid plist' > "$profile_dir/window-state.plist"
VOX_TEST_WINDOW=1 "$output_dir/window-state-test" malformed "$profile_dir/window-state.plist"
cat > "$profile_dir/window-state.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>version</key><integer>1</integer><key>normalFrame</key><string>{{0, 0}, {800, 600}}</string><key>maximized</key><array/><key>fullscreen</key><true/></dict></plist>
PLIST
VOX_TEST_WINDOW=1 "$output_dir/window-state-test" malformed "$profile_dir/window-state.plist"
