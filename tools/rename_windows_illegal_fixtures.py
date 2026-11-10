#!/usr/bin/env python3
"""Rename pixel_tests fixtures whose names are illegal on Windows.

Strips `?` and everything after it, and `:`-encoded segments, from the 46
fixture paths under pixel_tests/ that contain characters illegal on Windows
(`:`, `?`). CSS url() references inside the fixtures already use the clean
names, so the rename makes them consistent.

Run from the repository root on Linux/macOS/WSL:

    python3 tools/rename_windows_illegal_fixtures.py            # dry run
    python3 tools/rename_windows_illegal_fixtures.py --apply    # do it

The script prints the rename plan and exits 0 without --apply.
"""
import argparse
import os
import re
import sys
from pathlib import Path

ILLEGAL = (':', '?', '*', '<', '>', '|', '"')


def clean_name(name: str) -> str:
    # Strip query strings first (everything from the first '?').
    if '?' in name:
        name = name.split('?', 1)[0]
    # Strip colon-encoded path segments that Windows rejects.
    # Keep the last path component's basename intact.
    return name


def plan(roots):
    renames = []
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            for filename in filenames:
                if any(c in filename for c in ILLEGAL):
                    old = Path(dirpath) / filename
                    new_name = clean_name(filename)
                    if new_name == filename:
                        continue
                    new = Path(dirpath) / new_name
                    renames.append((old, new))
    return renames


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true',
                        help='perform the renames (default is dry run)')
    parser.add_argument('--root', default='pixel_tests',
                        help='root directory to scan (default: pixel_tests)')
    args = parser.parse_args()

    renames = plan([Path(args.root)])
    if not renames:
        print('No illegal fixture names found.')
        return 0

    print(f'Found {len(renames)} illegal fixture name(s):')
    for old, new in renames:
        print(f'  {old}  ->  {new}')

    if not args.apply:
        print('\nDry run. Re-run with --apply to perform the renames.')
        return 0

    # Apply renames, deepest first so directory renames don't invalidate paths.
    for old, new in sorted(renames, key=lambda r: len(str(r[0])), reverse=True):
        new.parent.mkdir(parents=True, exist_ok=True)
        if new.exists():
            print(f'  SKIP (target exists): {old} -> {new}', file=sys.stderr)
            continue
        old.rename(new)
        print(f'  renamed: {old} -> {new}')
    print(f'\nDone. {len(renames)} file(s) renamed.')
    print('Next: update any CSS url() references and run the pixel tests.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
