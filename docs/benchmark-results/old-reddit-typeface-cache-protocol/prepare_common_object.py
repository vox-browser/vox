#!/usr/bin/env python3
"""Compile the unchanged generated browser C once for exact native relinks."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys

root = Path(__file__).resolve().parent
repo = root.parent.parent
project = root / 'baseline-c'
output = root / 'common-object'
output.mkdir()
native = shlex.split((project / 'build.sh').read_text().splitlines()[2])
main_source = project / 'vox2.c'
command = [arg for arg in native if not (arg.endswith('.c') and arg != str(main_source))]
command[command.index('-o') + 1] = str(output / 'vox2.o')
command.append('-c')
identity = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
inputs = {str(main_source): identity(main_source),
          str(project / 'build.sh'): identity(project / 'build.sh')}
record = {'purpose': 'Unchanged browser object for source-identical baseline/candidate native relinks',
          'command': command, 'inputs': inputs}
(output / 'invocation.json').write_text(json.dumps(record, indent=2)+'\n')
result = subprocess.run(command, cwd=repo)
record.update(exit_code=result.returncode,
              inputs_unchanged=all(identity(path)==sha for path,sha in inputs.items()))
if result.returncode == 0:
    record['object_sha256'] = identity(output / 'vox2.o')
(output / 'result.json').write_text(json.dumps(record,indent=2)+'\n')
raise SystemExit(result.returncode if record['inputs_unchanged'] else 2)
