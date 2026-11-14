#!/usr/bin/env -S v -b c -memory-limit 10G run
import buildtools
import os
buildtools.main_command('prepare_windows_jsc', os.args[1..])
