#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$repo_dir/build-prod-browser.sh" "$@"
