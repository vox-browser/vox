#!/usr/bin/env python3
"""Temporary instruction-only probe coordinator; no regression assertions."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

binary, flag, label, *extra = sys.argv[1:]
root = Path('Build/github-20-instr')
binary = str(Path(binary).resolve())
identity = hashlib.sha256(Path(binary).read_bytes()).hexdigest()
results = []
for pair in range(3):
    for control in ([True, False] if pair % 2 == 0 else [False, True]):
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(('VOX_', 'LADYBIRD_', 'ZZ_'))}
        for argument in extra:
            key, value = argument.split('=', 1)
            env[key] = value
        if control:
            env[flag] = '1'
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        host_load = os.getloadavg()
        selected = str(Path(os.getenv('ZZ_CONTROL_BINARY', binary)).resolve()) if control else binary
        selected_identity = hashlib.sha256(Path(selected).read_bytes()).hexdigest()
        result = subprocess.run([selected], env=env, capture_output=True, text=True)
        log = root / f'{label}-{pair + 1}-{"control" if control else "candidate"}.log'
        log.write_text(result.stdout + result.stderr)
        rows = re.findall(r'LAYOUT pass=(\d+) instructions=(\d+) geometry=([0-9a-f]+)', result.stderr)
        parser_rows = re.findall(r'PARSER instructions=(\d+) rules=(\d+) sheets=(\d+)', result.stderr)
        entry = dict(pair=pair + 1, control=control, exit=result.returncode,
                     started=started, cpu_count=os.cpu_count(), host_load=host_load,
                     binary=selected, sha256=selected_identity, flag=flag,
                     passes=[dict(pass_index=int(p), instructions=int(n), geometry=h)
                             for p, n, h in rows],
                     parser=[dict(instructions=int(n), rules=int(r), sheets=int(s))
                             for n, r, s in parser_rows], log=str(log))
        results.append(entry)
        (root / f'{label}-counts.json').write_text(json.dumps(results, indent=2) + '\n')
        print(json.dumps(entry), flush=True)
        if result.returncode:
            sys.exit(result.returncode)
