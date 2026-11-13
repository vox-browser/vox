#!/bin/sh
set -eu
exec sh "$(dirname -- "$0")/run_v_tool.sh" v_match_scope_cc "$@"
