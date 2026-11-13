#!/usr/bin/env -S v -b c -memory-limit 10G run
import buildtools
import os
buildtools.main_command('production_source_manifest', os.args[1..])
