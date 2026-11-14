#!/usr/bin/env -S v -b c -memory-limit 10G run
import buildtools
import os
buildtools.main_command('v_match_scope_cc', os.args[1..])
