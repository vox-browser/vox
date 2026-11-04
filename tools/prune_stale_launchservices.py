#!/usr/bin/env python3
"""List or unregister LaunchServices records whose bundle no longer exists.

Deleted Build/ copies of Vox.app stay registered. AppKit's launch-time lookups
of the app's own bundle then compare every same-identifier record, which added
about 240M instructions to each Vox launch on a machine with ~470 stale copies.
Only records for missing paths are touched; existing bundles stay registered.

  python3 tools/prune_stale_launchservices.py            # report only
  python3 tools/prune_stale_launchservices.py --apply    # unregister them
"""
import argparse
import json
import os
import re
import subprocess
import sys

LSREGISTER = ('/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/'
              'LaunchServices.framework/Versions/A/Support/lsregister')
SEPARATOR = '-' * 80


def bundle_records(dump):
    """Yield (path, identifier) for each bundle record in an lsregister dump."""
    for record in dump.split(SEPARATOR):
        path = re.search(r'^path:\s+(.*?) \(0x[0-9a-f]+\)\s*$', record, re.M)
        if not path or not re.search(r'^(bundle id|name):', record, re.M):
            continue
        identifier = re.search(r'^identifier:\s+(\S+)', record, re.M)
        yield path.group(1), identifier.group(1) if identifier else ''


def stale_records(dump, exists=os.path.exists):
    stale = {}
    for path, identifier in bundle_records(dump):
        if not exists(path):
            stale.setdefault(path, identifier)
    return [dict(path=path, identifier=identifier) for path, identifier in sorted(stale.items())]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--apply', action='store_true', help='unregister the stale records')
    parser.add_argument('--identifier', help='limit to one bundle identifier, e.g. org.ladybirdbrowser.vox')
    parser.add_argument('--json', action='store_true', help='print the records as JSON')
    args = parser.parse_args(argv)
    dump = subprocess.run([LSREGISTER, '-dump'], capture_output=True, text=True, errors='replace', check=True).stdout
    stale = [r for r in stale_records(dump) if not args.identifier or r['identifier'] == args.identifier]
    failures = []
    if args.apply:
        for record in stale:
            # Recheck immediately before unregistering a path.
            if os.path.exists(record['path']):
                continue
            result = subprocess.run([LSREGISTER, '-u', record['path']], capture_output=True, text=True)
            if result.returncode != 0:
                failures.append(dict(record, error=result.stderr.strip()))
    if args.json:
        print(json.dumps(dict(stale=stale, applied=args.apply, failures=failures), indent=1))
    else:
        for record in stale:
            print(f"{record['identifier'] or '-'}\t{record['path']}")
        print(f"{len(stale)} stale record(s){'; unregistered' if args.apply else ''}"
              f"{f', {len(failures)} failed' if failures else ''}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
