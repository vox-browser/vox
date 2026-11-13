#!/usr/bin/env -S v -b c -memory-limit 10G run
// One executable can dispatch all build helpers, including focused migration checks.
import buildtools
import os
if os.args.len < 2 { eprintln('Expected a build tool name'); exit(2) }
buildtools.main_command(os.args[1], os.args[2..])
