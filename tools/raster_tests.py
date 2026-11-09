#!/usr/bin/env python3
"""Run the separate Vox raster suite at the revision pinned by this checkout."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PIN = Path(__file__).with_suffix('.json')


def git(checkout, *args):
    return subprocess.check_output(['git', '-C', str(checkout), *args], text=True).strip()


def validate_checkout(checkout, revision):
    if git(checkout, 'rev-parse', 'HEAD') != revision:
        raise ValueError('Raster suite revision differs from tools/raster_tests.json: ' + str(checkout))
    if git(checkout, 'status', '--porcelain', '--untracked-files=all'):
        raise ValueError('Raster suite has uncommitted changes: ' + str(checkout))


def ensure_checkout(repository, revision, checkout, fetch=True):
    if not re.fullmatch('[0-9a-f]{40}', revision):
        raise ValueError('Raster suite pin must be a full Git commit ID')
    checkout = Path(checkout)
    if not checkout.exists():
        if not fetch:
            raise ValueError('Raster suite checkout does not exist: ' + str(checkout))
        checkout.parent.mkdir(parents=True, exist_ok=True)
        temporary = Path(tempfile.mkdtemp(prefix='.vox-tests-', dir=checkout.parent))
        try:
            subprocess.run(['git', 'clone', '--quiet', '--no-checkout', repository, str(temporary)], check=True)
            subprocess.run(['git', '-C', str(temporary), 'checkout', '--quiet', '--detach', revision], check=True)
            validate_checkout(temporary, revision)
            try:
                temporary.rename(checkout)
            except FileExistsError:
                pass  # A concurrent fetch must still pass validation below.
        finally:
            if temporary.exists():
                shutil.rmtree(temporary)
    validate_checkout(checkout, revision)
    return checkout


def tool_path(checkout, name):
    if not re.fullmatch(r'[a-zA-Z0-9_]+\.(py|sh|v|cpp|txt)', name):
        raise ValueError('Expected a raster tool filename, without a directory')
    path = checkout / 'tools/gg_migration' / name
    if not path.is_file():
        raise ValueError('Raster tool is absent from the pinned suite: ' + name)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkout', type=Path, help='Use an existing clean checkout at the pinned revision')
    parser.add_argument('--path', action='store_true', help='Print a tool path instead of executing it')
    parser.add_argument('tool', nargs='?', help='Tool filename; omit to fetch and print the checkout path')
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    pin = json.loads(PIN.read_text())
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache'))
    checkout = args.checkout or cache / 'vox-tests' / pin['revision']
    try:
        checkout = ensure_checkout(pin['repository'], pin['revision'], checkout, fetch=args.checkout is None)
        if not args.tool:
            print(checkout)
            return 0
        path = tool_path(checkout, args.tool)
        if args.path:
            print(path)
            return 0
        interpreter = {'.py': [sys.executable], '.sh': ['sh']}.get(path.suffix)
        if interpreter is None:
            raise ValueError('Use --path for tools that need compilation')
        environment = dict(os.environ, VOX_SOURCE_DIR=str(ROOT))
        arguments = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
        result = subprocess.run([*interpreter, str(path), *arguments], cwd=ROOT, env=environment)
        validate_checkout(checkout, pin['revision'])
        return result.returncode
    except (ValueError, subprocess.CalledProcessError) as error:
        print('Raster tests: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
