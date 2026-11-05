#!/usr/bin/env python3
"""Counts the descriptors gg.canvas drew and declined in a capture_ab.py run
whose candidate had VOX_GG_DIAGNOSTICS=1: every `VOX_GG KIND KEY=VALUE...
drawn=0|1` line of the fixtures' candidate.log files.
Usage: summarize_gg_diagnostics.py CAPTURE_DIRECTORY [--json OUT]"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

root = Path(sys.argv[1])
totals = defaultdict(lambda: {'drawn': 0, 'declined': 0, 'fixtures': set()})
for log in sorted(root.glob('*/candidate.log')):
    for line in log.read_text(errors='replace').splitlines():
        match = re.match(r'VOX_GG (\S+) (.*) drawn=(\d)$', line)
        if not match:
            continue
        key = f'{match.group(1)} {match.group(2)}'
        entry = totals[key]
        entry['drawn' if match.group(3) == '1' else 'declined'] += 1
        entry['fixtures'].add(log.parent.name)
rows = {key: {'drawn': v['drawn'], 'declined': v['declined'], 'fixtures': len(v['fixtures'])}
        for key, v in sorted(totals.items())}
for kind in ('shape', 'path', 'svg'):
    drawn = sum(v['drawn'] for k, v in rows.items() if k.startswith(kind + ' '))
    declined = sum(v['declined'] for k, v in rows.items() if k.startswith(kind + ' '))
    print(f'{kind}: {drawn} drawn, {declined} declined')
for key, value in rows.items():
    print(f'  {key}: {value}')
if '--json' in sys.argv:
    Path(sys.argv[sys.argv.index('--json') + 1]).write_text(json.dumps(rows, indent=1))
