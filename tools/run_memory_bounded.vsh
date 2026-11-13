#!/usr/bin/env -S v -b c -memory-limit 10G run
import buildtools
import os
buildtools.main_command('run_memory_bounded', os.args[1..])
