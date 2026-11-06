#!/usr/bin/env python3
"""Select the default GG-capable compiler without replacing the shared V toolchain.

The current GG adapters still require Skia. Record that fact in build receipts;
renderer selection must never be mistaken for eliminating a linked dependency.
"""
import argparse
import json
from pathlib import Path
import sys

from gg_canvas_build import has_gg_canvas


def select_compiler(compiler, legacy=False, explicit=False, fallback=None):
    if legacy or has_gg_canvas(compiler):
        return compiler
    if not explicit and fallback and Path(fallback).is_file() and has_gg_canvas(fallback):
        print('GG default: selecting compiler ' + str(fallback), file=sys.stderr)
        return str(fallback)
    raise RuntimeError('The default renderer requires a V compiler with gg.canvas. '
                       'Set V_BIN to that compiler, or build the legacy renderer with VOX_USE_SKIA=1.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('compiler')
    parser.add_argument('--skia', choices=['0','1'], default='0')
    parser.add_argument('--explicit', action='store_true')
    parser.add_argument('--fallback', type=Path)
    parser.add_argument('--receipt', type=Path)
    args = parser.parse_args()
    compiler = select_compiler(args.compiler, args.skia == '1', args.explicit, args.fallback)
    if args.receipt:
        args.receipt.write_text(json.dumps(dict(default='skia' if args.skia == '1' else 'gg',
            compiler=compiler, gg_adapters=args.skia != '1', skia_free=False,
            skia_required_for=['text preparation and fallback', 'canvas', 'shadows',
                               'bitmap export', 'recording and picture playback']), indent=2)+'\n')
    print(compiler)


if __name__ == '__main__':
    try:
        main()
    except RuntimeError as error:
        raise SystemExit(str(error))
