#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${PIKABU_NETWORK_TEST_OUTPUT_DIR:-"$repo_dir/Build/pikabu-network-deny-test"}
mkdir -p "$output_dir"
clang -O2 -Wall -Wextra -Werror -dynamiclib \
    "$repo_dir/tools/pikabu_instruction_network_deny.c" -o "$output_dir/network-deny.dylib"
clang -O2 -Wall -Wextra -Werror \
    "$repo_dir/tools/pikabu_instruction_network_deny_test.c" -o "$output_dir/network-deny-test"
DYLD_INSERT_LIBRARIES="$output_dir/network-deny.dylib" "$output_dir/network-deny-test"
echo 'Offline guard: DNS, connect and connectx passed for IPv4 and IPv6'
