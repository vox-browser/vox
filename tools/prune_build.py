#!/usr/bin/env python3
"""Keep Build/ bounded by removing idle per-job scratch.

Build/ keeps the shared bundle and its libraries (Build/v), native dependency
caches, the production build state and the verified pixel diff tool.
Everything else is per-job scratch: measurement outputs, memory-guard locks
and reports, test binaries and temporary build directories. An entry is
removed once nothing below it changed for --idle-hours and no process has a
file below it open or uses it as its working directory.

Production receipts keep only small records: the generated C and sealed
compiler inputs stay with the published and the newest receipt, and only the
newest RETAINED_RECEIPTS receipts are kept. Content-addressed runtimes under
Build/v keep the two most recently used digests and any used recently.
"""
import argparse
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
KEEP = frozenset({'v', 'deps', 'libregex', 'linux', 'production-build', 'pixel-tools',
                  'release.lock', '.DS_Store'})
# Build/v also holds the published bundle, its libraries and module caches;
# only these entries are scratch.
V_SCRATCH_PREFIXES = ('compiler-output.',)
V_SCRATCH_NAMES = frozenset({'Vox-profile', 'Vox-profile.c', 'address-bar-tests', 'settings-tests'})
RUNTIME_CACHES = ('prealloc-runtime', 'font-runtime', 'native-gg-runtime')
RETAINED_RUNTIMES = 2
RECEIPT_PAYLOADS = ('generated', 'frozen-compiler-inputs')
RETAINED_RECEIPTS = 20
DEFAULT_IDLE_HOURS = 12


def held_paths(build):
    """Every path under Build/ that contains a file or working directory a process holds.

    Lock holders keep their lock file open, so this also covers held locks
    without probing them (a probe could make a non-blocking waiter fail).
    """
    try:
        result = subprocess.run(['lsof', '-nP', '-Fn'], capture_output=True, timeout=300)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if not result.stdout:
        return None
    build = build.resolve()
    prefix = os.fsencode(str(build)) + b'/'
    held = set()
    for line in result.stdout.splitlines():
        if line.startswith(b'n') and line[1:].startswith(prefix):
            path = Path(os.fsdecode(line[1:]))
            while path != build and path not in held:
                held.add(path)
                path = path.parent
    return held


def scan(path):
    """Return (newest mtime, allocated bytes) for a whole subtree."""
    newest, size = 0.0, 0
    stack = [path]
    while stack:
        current = stack.pop()
        try:
            info = os.lstat(current)
        except OSError:
            continue
        newest = max(newest, info.st_mtime)
        size += info.st_blocks * 512
        if stat.S_ISDIR(info.st_mode):
            try:
                stack.extend(entry.path for entry in os.scandir(current))
            except OSError:
                pass
    return newest, size


def remove(path):
    def writable(function, name, _):
        # Copied bundles and sealed inputs can contain read-only directories.
        if function not in (os.unlink, os.rmdir):
            raise
        os.chmod(os.path.dirname(name), 0o755)
        function(name)
    def delete():
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path, onerror=writable)
        else:
            path.unlink(missing_ok=True)
    try:
        delete()
    except PermissionError:
        # Some jobs "sealed" copied inputs with user-immutable flags.
        if sys.platform != 'darwin':
            raise
        subprocess.run(['chflags', '-R', 'nouchg,nouappnd', str(path)], capture_output=True)
        delete()


def retire(path, reason, dry_run, report, size=None):
    if size is None:
        size = scan(str(path))[1]
    if not dry_run:
        try:
            remove(path)
        except OSError as error:
            # macOS protects launched app bundles (App Management); keep going.
            report.append((0, str(path), 'not removed: ' + error.strerror))
            return
    report.append((size, str(path), reason))


def published_receipt(state):
    latest = state / 'latest.json'
    if not latest.is_file():
        return None
    published = latest.read_bytes()
    for result in (state / 'receipts').glob('*/result.json'):
        if result.read_bytes() == published:
            return result.parent
    return None


def prune_receipts(build, dry_run=False, report=None, keep=RETAINED_RECEIPTS):
    """Drop receipt payloads except for the published and newest receipts.

    A running build only writes its own (newest) receipt, so this needs no
    build lock and never delays a build request.
    """
    report = [] if report is None else report
    state = build / 'production-build'
    receipts = sorted(path for path in (state / 'receipts').glob('*') if path.is_dir())
    if not receipts:
        return report
    protected = {receipts[-1], published_receipt(state)}
    for index, receipt in enumerate(receipts):
        if receipt in protected:
            continue
        if index < len(receipts) - keep:
            retire(receipt, 'old production receipt', dry_run, report)
            continue
        for name in RECEIPT_PAYLOADS:
            if (receipt / name).exists():
                retire(receipt / name, 'receipt payload', dry_run, report)
    return report


def prune_runtimes(build, idle, held, dry_run, report):
    now = time.time()
    for cache in RUNTIME_CACHES:
        root = build / 'v' / cache
        if not root.is_dir():
            continue
        # The stagers touch a digest directory whenever a build reuses it.
        digests = sorted((path for path in root.iterdir() if path.is_dir()),
                         key=lambda path: path.stat().st_mtime, reverse=True)
        for digest in digests[RETAINED_RUNTIMES:]:
            lock = root / (digest.name + '.lock')
            if now - digest.stat().st_mtime < idle or digest.resolve() in held or lock.resolve() in held:
                continue
            retire(digest, 'unused runtime', dry_run, report)
            if lock.exists():
                retire(lock, 'unused runtime lock', dry_run, report, size=0)


def prune(root=ROOT, idle_hours=DEFAULT_IDLE_HOURS, dry_run=False):
    build = root / 'Build'
    if not build.is_dir():
        return []
    held = held_paths(build)
    if held is None:
        raise RuntimeError('lsof is unavailable; cannot tell which Build/ entries are in use')
    idle, now, report = idle_hours * 3600, time.time(), []
    candidates = [(path, 'idle job output') for path in build.iterdir() if path.name not in KEEP]
    bundle = build / 'v'
    if bundle.is_dir():
        candidates += [(path, 'idle build scratch') for path in bundle.iterdir()
                       if path.name in V_SCRATCH_NAMES or path.name.startswith(V_SCRATCH_PREFIXES)]
    for path, reason in candidates:
        newest, size = scan(str(path))
        if now - newest < idle or path.resolve() in held:
            continue
        retire(path, reason, dry_run, report, size)
    prune_receipts(build, dry_run, report)
    prune_runtimes(build, idle, held, dry_run, report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--idle-hours', type=float, default=DEFAULT_IDLE_HOURS)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--verbose', action='store_true')
    args = parser.parse_args()
    report = prune(ROOT, args.idle_hours, args.dry_run)
    failed = [item for item in report if item[2].startswith('not removed')]
    removed = [item for item in report if not item[2].startswith('not removed')]
    if args.verbose:
        for size, path, reason in sorted(removed, reverse=True):
            print(f'{size / 2**20:10.1f} MiB  {reason}: {path}')
    for _, path, reason in failed:
        print(f'{reason}: {path}', file=sys.stderr)
    total = sum(size for size, _, _ in removed)
    verb = 'Would remove' if args.dry_run else 'Removed'
    print(f'{verb} {len(removed)} Build/ entries ({total / 2**30:.2f} GiB)'
          + (f'; {len(failed)} could not be removed' if failed else ''))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
