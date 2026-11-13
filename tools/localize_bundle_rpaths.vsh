#!/usr/bin/env -S v -b c -memory-limit 10G run
import buildtools
import os
buildtools.main_command('localize_bundle_rpaths', os.args[1..])
