#!/usr/bin/env python3
"""Reject generated measurement dumps, evidence archives and build output.

Generated measurement JSON and evidence archives stay local; commit a concise
Markdown summary instead. Build/ is local scratch. The pre-commit hook
installed by `python3 tools/rebuild_browser.py --install-hook` runs this.
"""
import subprocess
import sys

ARCHIVE_SUFFIXES = ('.gz', '.tgz', '.zip', '.tar', '.xz', '.zst', '.7z', '.bz2', '.tbz2',
                    '.txz', '.rar')
# Runtime assets and test fixtures that are archives by format.
ARCHIVE_DIRECTORIES = ('adblock/', 'tools/adblock/fixtures/', 'Tests/Browser/Brave/candidates/')
MEASUREMENT_DIRECTORIES = ('docs/performance/', 'docs/benchmark-results/')
MEASUREMENT_SUFFIXES = ('.json', '.jsonl', '.ndjson')
MAX_BYTES = 32 * 2**20


def staged_blobs(root='.'):
    """Return (path, blob) for every staged addition or modification."""
    output = subprocess.run(['git', '-C', str(root), 'diff', '--cached', '--raw', '-z',
                             '--no-renames', '--no-abbrev', '--diff-filter=ACM'],
                            check=True, capture_output=True).stdout
    fields = output.split(b'\0')
    entries = []
    for header, path in zip(fields[0::2], fields[1::2]):
        mode, blob = header.split()[1], header.split()[3]
        if mode != b'160000':
            entries.append((path.decode('utf-8', 'surrogateescape'), blob.decode()))
    return entries


def blob_sizes(root, blobs):
    if not blobs:
        return {}
    output = subprocess.run(['git', '-C', str(root), 'cat-file', '--batch-check=%(objectname) %(objectsize)'],
                            input='\n'.join(blobs) + '\n', check=True, capture_output=True,
                            text=True).stdout
    return {name: int(size) for name, size in (line.split() for line in output.splitlines())}


def violations(root='.', max_bytes=MAX_BYTES):
    entries = staged_blobs(root)
    sizes = blob_sizes(root, sorted({blob for _, blob in entries}))
    problems = []
    for path, blob in entries:
        if path == 'Build' or path.startswith('Build/'):
            problems.append(f'{path}: Build/ is local scratch')
        elif path.startswith(MEASUREMENT_DIRECTORIES) and path.lower().endswith(MEASUREMENT_SUFFIXES):
            problems.append(f'{path}: measurement dumps stay local; commit a Markdown summary instead')
        elif path.lower().endswith(ARCHIVE_SUFFIXES) and not path.startswith(ARCHIVE_DIRECTORIES):
            problems.append(f'{path}: archives stay local; commit the report or manifest instead')
        elif sizes[blob] > max_bytes:
            problems.append(f'{path}: {sizes[blob] / 2**20:.1f} MiB exceeds the '
                            f'{max_bytes / 2**20:.0f} MiB limit')
    return problems


def main():
    problems = violations()
    if not problems:
        return 0
    print('Commit rejected by tools/pre_commit_check.py:', file=sys.stderr)
    for problem in problems:
        print('  ' + problem, file=sys.stderr)
    print('Unstage these with `git restore --staged PATH` and keep them out of the '
          'repository.', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
