#!/usr/bin/env python3
"""Inventory an official upstream WPT manifest; this does not execute tests.

Generate the manifest with upstream's `wpt manifest --no-download --no-parallel`.
Counts are source files and manifest variants, never runtime subtests. Support
files and specification metadata are retained separately from test counts.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import unquote

from wpt_compare import discover_tests


NON_TEST_TYPES = {'support', 'spec'}


def manifest_leaves(tree, parts=()):
    if isinstance(tree, dict):
        for name, child in tree.items():
            yield from manifest_leaves(child, parts + (name,))
        return
    if (not parts or not isinstance(tree, list) or len(tree) < 2
            or not isinstance(tree[0], str)
            or any(not isinstance(item, list) for item in tree[1:])):
        raise ValueError(f'Invalid manifest entry at {"/".join(parts)}')
    yield '/'.join(parts), tree[1:]


def inventory_manifest(manifest):
    if manifest.get('version') != 9:
        raise ValueError('Expected official WPT manifest version 9')
    if manifest.get('url_base') != '/' or not isinstance(manifest.get('items'), dict):
        raise ValueError('Expected a complete root WPT manifest')
    counts = {}
    harness_urls = set()
    for kind, tree in sorted(manifest['items'].items()):
        files = variants = 0
        for path, items in manifest_leaves(tree):
            files += 1
            if kind in NON_TEST_TYPES:
                continue
            variants += len(items)
            if kind == 'testharness':
                for item in items:
                    if len(item) != 2 or (item[0] is not None and not isinstance(item[0], str)):
                        raise ValueError(f'Invalid testharness variant at {path}')
                    harness_urls.add('/' + unquote(item[0] if item[0] is not None else path))
        counts[kind] = dict(source_files=files, test_variants=variants)
    return dict(
        types=counts,
        manifest_source_files=sum(row['source_files'] for row in counts.values()),
        test_source_files=sum(row['source_files'] for kind, row in counts.items()
                              if kind not in NON_TEST_TYPES),
        test_variants=sum(row['test_variants'] for row in counts.values()),
        subtests=None), harness_urls


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()


def create_inventory(wpt_root, manifest_path, imported_root=None):
    before = git(wpt_root, 'rev-parse', 'HEAD')
    changes = git(wpt_root, 'status', '--porcelain', '--untracked-files=no')
    if changes:
        raise ValueError('Upstream WPT tracked files are modified')
    payload = manifest_path.read_bytes()
    result, harness_urls = inventory_manifest(json.loads(payload))
    result.update(
        scope='full upstream WPT manifest inventory; no tests executed',
        upstream=dict(root=str(wpt_root.resolve()), revision=before,
                      tracked_files=len(subprocess.check_output(
                          ['git', '-C', str(wpt_root), 'ls-files', '-z']).split(b'\0')) - 1),
        manifest=dict(path=str(manifest_path.resolve()), version=9,
                      sha256=hashlib.sha256(payload).hexdigest(), bytes=len(payload)))
    if imported_root is not None:
        tests = discover_tests(imported_root)
        expected_root = imported_root / 'expected' / 'wpt-import'
        if not expected_root.is_dir():
            raise ValueError(f'Missing imported expectations: {expected_root}')
        result['imported_cohort'] = dict(
            root=str(imported_root.resolve()),
            scope='Ladybird expectation-selected testharness subset; static HTTP server',
            expectation_files=sum(1 for _ in expected_root.rglob('*.txt')),
            selected_files_or_query_variants=len(tests),
            literal_upstream_testharness_url_matches=sum(
                unquote(test['url']) in harness_urls for test in tests),
            note='Matching URLs do not establish identical test bytes across revisions.')
    if git(wpt_root, 'rev-parse', 'HEAD') != before or git(
            wpt_root, 'status', '--porcelain', '--untracked-files=no'):
        raise ValueError('Upstream WPT inputs changed during inventory')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wpt-root', required=True, type=Path)
    parser.add_argument('--manifest', required=True, type=Path)
    parser.add_argument('--imported-root', type=Path,
                        help="Ladybird Tests/LibWeb/Text directory for scope comparison")
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = create_inventory(args.wpt_root, args.manifest, args.imported_root)
    output = json.dumps(result, indent=2) + '\n'
    if args.output:
        with args.output.open('x') as file:
            file.write(output)
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
