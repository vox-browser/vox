#!/bin/sh
set -eu

export VOX_CHROME_TEST_FILE=browserapp/browser_tabs_test.v
exec sh "$(dirname -- "$0")/test_address_bar.sh" "$@"
