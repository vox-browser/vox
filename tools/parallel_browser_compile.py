#!/usr/bin/env python3
"""Compile the production browser with V's -parallel-cc, or report that it needs one C unit.

usage: parallel_browser_compile.py --receipt DIR --output PATH -- V_COMPILER V_ARGS... INPUT

V splits the generated C into units, compiles them concurrently and links OUTPUT.
Exit status 0 with OUTPUT present means the split build finished. Exit status 0
without OUTPUT means this compiler cannot split the browser: it lacks the
native-header -parallel-cc support, or native code (a mutable `static`, for
example) would be duplicated in every unit. The caller then compiles one unit.
Any other status is the compiler's own failure. The decision is written to
DIR/c-compile.json for the build receipt.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

# A V driver that can refuse the one-unit fallback (status 3) also splits programs
# whose native directives include project headers. Older drivers would silently
# compile one large unit inside the resident compiler instead.
REQUIRE_SPLIT = 'V3_PARALLEL_CC_REQUIRE_SPLIT'
REFUSED_STATUS = 3
REFUSED_TEXT = 'cannot split this program into C units'


def compiler_supports_split(compiler):
    marker = REQUIRE_SPLIT.encode()
    tail = b''
    with open(compiler, 'rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            if marker in tail + block:
                return True
            tail = block[-len(marker):]
    return False


def write_record(receipt, record):
    path = Path(receipt) / 'c-compile.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--receipt', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if len(command) < 2:
        parser.error('expected -- V_COMPILER ... INPUT')
    compiler, options, source = command[0], command[1:-1], command[-1]
    output = Path(args.output)
    record = dict(requested='parallel', compiler=compiler, v_prod='-prod' in options)
    if not compiler_supports_split(compiler):
        record.update(mode='single', fallback=f'{compiler} cannot split programs with native '
                      f'project headers (no {REQUIRE_SPLIT} support)')
        write_record(args.receipt, record)
        print('Parallel C: ' + record['fallback'] + '; compiling one C unit.', flush=True)
        return 0
    environment = dict(os.environ, **{REQUIRE_SPLIT: '1'})
    process = subprocess.Popen([compiler, *options, '-parallel-cc', '-o', str(output), source],
                               env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = []
    for raw in process.stdout:
        line = raw.decode(errors='replace')
        lines.append(line)
        sys.stdout.write(line)
        sys.stdout.flush()
    status = process.wait()
    text = ''.join(lines)
    if status == REFUSED_STATUS and REFUSED_TEXT in text:
        output.unlink(missing_ok=True)
        reasons = [line.strip() for line in lines if line.startswith('parallel C:')
                   or re.match(r'  \S+:\d+: ', line)][:41]
        record.update(mode='single', fallback='native code would be duplicated in every C unit',
                      reasons=reasons)
        write_record(args.receipt, record)
        print('Parallel C: native code cannot be split; compiling one C unit.', flush=True)
        return 0
    if status:
        record.update(mode='failed', exit=status)
        write_record(args.receipt, record)
        return status
    if not output.is_file():
        record.update(mode='failed', exit=1, error='the compiler reported success without ' + str(output))
        write_record(args.receipt, record)
        print('Parallel C: ' + record['error'], file=sys.stderr, flush=True)
        return 1
    units = re.search(r'^parallel C: (\d+) units', text, re.M)
    record.update(mode='parallel', units=int(units.group(1)) if units else None)
    write_record(args.receipt, record)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
