#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/vox-test-window.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
clang -Wall -Wextra -Werror -Wno-deprecated-declarations -framework Cocoa \
    "$repo_dir/tools/native_test_window_test.m" -o "$test_dir/window-test"
"$test_dir/window-test"
