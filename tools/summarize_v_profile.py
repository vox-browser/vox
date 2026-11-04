#!/usr/bin/env python3
"""Rank V -profile rows without treating instrumented wall time as CPU work."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROW = re.compile(r'^\s*(\d+)\s+(-?\d+(?:\.\d+)?)ms\s+'
                 r'(-?\d+(?:\.\d+)?)ms\s+(-?\d+(?:\.\d+)?)ns\s+(\S+)\s*$')


def parse_profile(text):
    rows, names = [], set()
    for line in text.splitlines():
        match = ROW.fullmatch(line)
        if match is None:
            if re.match(r'^\s*\d+\s+\S*ms\s+', line):
                raise ValueError('Malformed V profile row: ' + line)
            continue
        calls, inclusive, self_time, average, name = match.groups()
        if name in names:
            raise ValueError('Duplicate V profile function; separate process reports: ' + name)
        names.add(name)
        row = dict(function=name, calls=int(calls), inclusive_ms=float(inclusive),
                   self_ms=float(self_time), average_inclusive_ns=float(average))
        if row['calls'] == 0 or row['inclusive_ms'] < 0 or row['average_inclusive_ns'] < 0:
            raise ValueError('Invalid V profile counter: ' + line)
        rows.append(row)
    if not rows:
        raise ValueError('No V -profile rows found')
    return rows


def summarize(rows, limit=20):
    if limit <= 0:
        raise ValueError('The ranking limit must be positive')
    return dict(
        functions=len(rows),
        inclusive=sorted(rows, key=lambda row: (-row['inclusive_ms'], row['function']))[:limit],
        self=sorted(rows, key=lambda row: (-row['self_ms'], row['function']))[:limit],
        calls=sorted(rows, key=lambda row: (-row['calls'], row['function']))[:limit],
        negative_self_rows=[row for row in rows if row['self_ms'] < 0],
        interpretation='Instrumented elapsed time. Self includes native/JSC callees, waits and '
                       'uninstrumented/inlined functions. Inclusive rows overlap; do not sum them. '
                       'Counter overhead changes the workload. No CPU instruction, unprofiled '
                       'speedup or Brave acceptance claim.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', type=Path)
    parser.add_argument('--limit', type=int, default=20)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    raw = args.profile.read_bytes()
    result = summarize(parse_profile(raw.decode()), args.limit)
    result.update(source=str(args.profile), source_sha256=hashlib.sha256(raw).hexdigest())
    text = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.write_text(text)
    else:
        print(text, end='')


if __name__ == '__main__':
    main()
