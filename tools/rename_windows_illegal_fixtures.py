#!/usr/bin/env python3
"""Rename pixel_tests fixtures whose names are illegal on Windows.

Maps fixture paths under pixel_tests/ that contain characters illegal on
Windows (`:`, `?`) to portable names: query strings (from the first `?`)
are stripped and the remaining `:` separators become `_`. CSS url()
references inside the fixtures already use the clean names, so the rename
makes them consistent.

Targets that already exist with identical bytes are recorded as removals
(the old illegal name goes away, no data is lost); targets with different
bytes get a deterministic `~N` suffix. Names that still contain illegal
characters after mapping are reported as unsupported and never touched.

Run from the repository root on Linux/macOS/WSL:

    python3 tools/rename_windows_illegal_fixtures.py            # dry run
    python3 tools/rename_windows_illegal_fixtures.py --apply    # do it

The script prints the rename plan and exits 0 without --apply.
"""
import argparse
import hashlib
import os
import sys
from pathlib import Path

ILLEGAL = (':', '?', '*', '<', '>', '|', '"')


def clean_name(name: str) -> str:
    # Strip query strings first (everything from the first '?'), then map
    # the remaining colon separators Windows rejects to underscores.
    if '?' in name:
        name = name.split('?', 1)[0]
    return name.replace(':', '_')


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resolve_collision(directory: Path, candidate: str, old: Path):
    """Find a free target for candidate, or return None for duplicates."""
    stem, dot, suffix = candidate.rpartition('.')
    if not dot:
        stem, suffix = candidate, ''
    for index in range(1, 1000):
        trial = Path(directory) / f'{stem}~{index}{dot}{suffix}'
        if not trial.exists():
            return trial
        if trial.is_file() and digest(trial) == digest(old):
            return None
    return None


def plan(roots):
    """Return (renames, removals, notes).

    renames maps old paths to new ones; removals holds old paths whose
    bytes already exist under a legal name; notes holds (path, reason)
    for unsupported names.
    """
    renames = []
    removals = []
    notes = []
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            for filename in filenames:
                if not any(c in filename for c in ILLEGAL):
                    continue
                old = Path(dirpath) / filename
                candidate = clean_name(filename)
                remaining = sorted({c for c in ILLEGAL if c in candidate})
                if not candidate or remaining:
                    notes.append((old, 'unsupported characters remain: '
                                       + ''.join(remaining)
                                       if remaining else 'empty name'))
                    continue
                new = Path(dirpath) / candidate
                if new == old:
                    notes.append((old, 'no portable mapping'))
                    continue
                if new.exists():
                    if new.is_file() and digest(new) == digest(old):
                        removals.append(old)
                        continue
                    new = resolve_collision(Path(dirpath), candidate, old)
                    if new is None:
                        removals.append(old)
                        continue
                renames.append((old, new))
    return renames, removals, notes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true',
                        help='perform the renames (default is dry run)')
    parser.add_argument('--root', default='pixel_tests',
                        help='root directory to scan (default: pixel_tests)')
    args = parser.parse_args()

    renames, removals, notes = plan([Path(args.root)])
    if not renames and not removals and not notes:
        print('No illegal fixture names found.')
        return 0

    if renames:
        print(f'Found {len(renames)} rename(s):')
        for old, new in renames:
            print(f'  {old}  ->  {new}')
    if removals:
        print(f'Found {len(removals)} duplicate(s) to remove (bytes kept):')
        for old in removals:
            print(f'  {old}')
    if notes:
        print(f'Found {len(notes)} unsupported name(s), left untouched:')
        for old, reason in notes:
            print(f'  {old}  ({reason})')

    if not args.apply:
        print('\nDry run. Re-run with --apply to perform the renames.')
        return 0

    # Apply renames, deepest first so directory renames don't invalidate paths.
    for old, new in sorted(renames, key=lambda r: len(str(r[0])), reverse=True):
        new.parent.mkdir(parents=True, exist_ok=True)
        old.rename(new)
        print(f'  renamed: {old} -> {new}')
    for old in removals:
        old.unlink()
        print(f'  removed duplicate: {old}')
    print(f'\nDone. {len(renames)} renamed, {len(removals)} duplicates removed.')
    print('Next: update any CSS url() references and run the pixel tests.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
