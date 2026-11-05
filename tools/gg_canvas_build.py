#!/usr/bin/env python3
"""Detect gg.canvas in the library actually selected by a V compiler."""
from pathlib import Path
import sys
import tempfile

from prepare_http_compat import compiler_vlib


def has_gg_canvas(compiler):
    # The GG compiler predates the `v root` command. The existing build probe
    # uses @VEXEROOT and also handles moved compilers and staged runtimes.
    with tempfile.TemporaryDirectory(prefix='vox-gg-library-') as temporary:
        vlib = compiler_vlib(compiler, Path(temporary))
    return (vlib / 'gg/canvas').is_dir()


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: gg_canvas_build.py V_COMPILER')
    print(int(has_gg_canvas(sys.argv[1])))
