#!/usr/bin/env python3
"""Seal legacy GitHub bodies into a shared, offline native/CDP fixture.

Response metadata is synthetic fixture policy, not recovered HTTP provenance.
Every original body is archived; only discovered, hash-matched URLs are served.
Use a separate network guard for Vox: a disk-cache miss can otherwise fetch.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
from urllib.parse import urldefrag, urljoin, urlsplit


URL = 'https://github.com/vlang/v'
MANIFEST = 'fixture-manifest.json'
POLICY = ('Synthetic status 200, inferred Content-Type, wildcard CORS and no-store. '
          'Original response status, headers, redirects and credentials were not archived. '
          'Unknown URLs and non-GET requests must fail; no live fallback is authorized.')
MAX_BODY = 16 * 1024 * 1024


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def source_fingerprint(source):
    """Historical GitHub receipt: sorted relative filename + NUL + raw bytes."""
    source = Path(source)
    rows, digest = [], hashlib.sha256()
    for path in sorted(source.rglob('*')):
        if path.is_symlink():
            raise ValueError('Source fixture contains a symlink: ' + str(path))
        if not path.is_file():
            continue
        relative = path.relative_to(source).as_posix()
        if (len(path.relative_to(source).parts) != 2 or
                path.parent.name not in ('pages', 'resources') or
                re.fullmatch(r'[0-9a-f]{64}', path.name) is None):
            raise ValueError('Source must contain only legacy pages/resources bodies: ' + relative)
        body = path.read_bytes()
        if not 0 < len(body) <= MAX_BODY:
            raise ValueError('Invalid source body size: ' + relative)
        digest.update(relative.encode() + b'\0' + body)
        rows.append(dict(path=relative, bytes=len(body), sha256=sha256(body)))
    if not rows:
        raise ValueError('Source fixture is empty')
    return dict(sha256=digest.hexdigest(), files=rows)


def absolute_url(base, reference):
    result = urldefrag(urljoin(base, reference.strip()))[0]
    return result if urlsplit(result).scheme in ('http', 'https') else None


def css_references(text):
    # Discovery is deliberately limited to explicit CSS references. A missed
    # reference remains blocked; nothing is fabricated or fetched to fill it.
    for match in re.finditer(r'''url\(\s*(['"]?)(.*?)\1\s*\)|@import\s+(['"])(.*?)\3''', text,
                             flags=re.IGNORECASE | re.DOTALL):
        yield (match.group(2) if match.group(2) is not None else match.group(4)), 'Other'


class HTMLReferences(HTMLParser):
    def __init__(self, base):
        super().__init__(convert_charrefs=True)
        self.base, self.references, self.in_style = base, [], False
        self.has_base = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'base' and attrs.get('href') and not self.has_base:
            self.base = urljoin(self.base, attrs['href'])
            self.has_base = True
        if tag == 'style':
            self.in_style = True
        for key in ('href', 'src', 'poster', 'data'):
            if attrs.get(key) and tag != 'base':
                kind = ('Script' if tag == 'script' else
                        'Stylesheet' if tag == 'link' and
                        'stylesheet' in attrs.get('rel', '').lower().split() else
                        'Image' if tag in ('img', 'image') or key == 'poster' else 'Other')
                self.references.append((attrs[key], kind))
        for candidate in attrs.get('srcset', '').split(','):
            if candidate.strip():
                self.references.append((candidate.strip().split()[0], 'Image'))
        self.references.extend(css_references(attrs.get('style', '')))

    def handle_endtag(self, tag):
        if tag == 'style':
            self.in_style = False

    def handle_data(self, data):
        if self.in_style:
            self.references.extend(css_references(data))


def inferred_mime(url, resource_type, category):
    if category == 'pages' or resource_type == 'Document':
        return 'text/html; charset=utf-8'
    extension = Path(urlsplit(url).path).suffix.lower()
    types = {'.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript',
             '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
             '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp',
             '.avif': 'image/avif', '.ico': 'image/vnd.microsoft.icon',
             '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
             '.otf': 'font/otf', '.json': 'application/json'}
    return types.get(extension, {'Script': 'text/javascript', 'Stylesheet': 'text/css',
                                'Font': 'font/woff2'}.get(resource_type, 'application/octet-stream'))


def seal_fixture(source, output, replay_results, expected_source_sha256, entry_url=URL):
    source, output = Path(source).resolve(), Path(output).resolve()
    if output == source or source in output.parents:
        raise ValueError('Output must be outside the source fixture')
    original = source_fingerprint(source)
    if original['sha256'] != expected_source_sha256:
        raise ValueError('Original fixture SHA256 mismatch')
    pending, ledgers = deque([(entry_url, 'Document', None)]), []
    for result_path in replay_results:
        result_path = Path(result_path)
        raw = result_path.read_bytes()
        result = json.loads(raw)
        if result.get('cache_sha256', expected_source_sha256) != expected_source_sha256:
            raise ValueError('Replay ledger references a different source fixture')
        requests = result.get('requests')
        if not isinstance(requests, list):
            raise ValueError('Replay result must contain a request ledger')
        ledgers.append(dict(path=str(result_path.resolve()), sha256=sha256(raw)))
        for row in requests:
            if row.get('method') == 'GET':
                pending.append((row['url'], row.get('resource_type', 'Other'),
                                row.get('sha256') if row.get('action') == 'replayed' else None))
    served, missing, seen, used = {}, set(), set(), set()
    while pending:
        raw_url, kind, expected_body = pending.popleft()
        url = absolute_url(entry_url, raw_url)
        if not url:
            continue
        key = sha256(url.encode())
        categories = ('pages', 'resources') if kind == 'Document' else ('resources', 'pages')
        candidates = [source / category / key for category in categories if (source / category / key).is_file()]
        if not candidates:
            if expected_body:
                raise ValueError('Replay ledger body is missing: ' + url)
            missing.add(url)
            continue
        path = candidates[0]
        body = path.read_bytes()
        if any(candidate.read_bytes() != body for candidate in candidates[1:]):
            raise ValueError('Conflicting page/resource bodies for URL: ' + url)
        if expected_body and sha256(body) != expected_body:
            raise ValueError('Replay ledger body SHA256 mismatch: ' + url)
        if url in served:
            row = served[url]
            row['resource_types'] = sorted(set(row['resource_types']) | {kind})
            if kind == 'Document' and not row['document']:
                row['document'] = True
                row['native_paths'].append('pages/' + key)
            continue
        category = path.parent.name
        mime = inferred_mime(url, kind, category)
        headers = [dict(name='Content-Type', value=mime),
                   dict(name='Content-Length', value=str(len(body))),
                   dict(name='Access-Control-Allow-Origin', value='*'),
                   dict(name='Cache-Control', value='no-store')]
        document = category == 'pages' or kind == 'Document'
        native_paths = ['resources/' + key] + (['pages/' + key] if document else [])
        served[url] = dict(url=url, source_path=path.relative_to(source).as_posix(),
                           category=category, sha256=sha256(body), bytes=len(body),
                           status=200, mime=mime, headers=headers, document=document,
                           resource_types=[kind], native_paths=native_paths)
        used.add(path.relative_to(source).as_posix())
        if url in seen:
            continue
        seen.add(url)
        text = body.decode('utf-8', errors='replace')
        base = url
        if mime.startswith('text/html'):
            parser = HTMLReferences(url)
            parser.feed(text)
            references, base = parser.references, parser.base
        elif mime.startswith('text/css'):
            references = css_references(text)
        else:
            references = []
        for reference, resource_type in references:
            absolute = absolute_url(base, reference)
            if absolute:
                pending.append((absolute, resource_type, None))
    if entry_url not in served or not served[entry_url]['document']:
        raise ValueError('Entry document is absent from the source fixture')
    # Exclusive creation preserves failed/completed attempts. Originals that
    # lack a known URL are archived outside native cache categories.
    output.mkdir(parents=True, exist_ok=False)
    for row in original['files']:
        target = output / 'original' / row['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / row['path'], target)
        if sha256(target.read_bytes()) != row['sha256']:
            raise ValueError('Original body changed while archiving: ' + row['path'])
    for row in served.values():
        body = (source / row['source_path']).read_bytes()
        for relative in row['native_paths']:
            target = output / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(body)
            Path(str(target) + '.url').write_text(row['url'])
            Path(str(target) + '.headers.json').write_bytes(encoded(row['headers']))
            Path(str(target) + '.status').write_text('200')
            Path(str(target) + '.content-type').write_text(row['mime'])
    if source_fingerprint(source) != original:
        raise ValueError('Original fixture changed while sealing')
    inventory = [dict(path=path.relative_to(output).as_posix(), bytes=path.stat().st_size,
                      sha256=sha256(path.read_bytes()))
                 for path in sorted(output.rglob('*')) if path.is_file()]
    manifest = dict(schema=1, entry_url=entry_url, metadata_policy=POLICY,
                    source=original, replay_ledgers=ledgers,
                    responses=sorted(served.values(), key=lambda row: row['url']),
                    unresolved_source_paths=sorted(set(row['path'] for row in original['files']) - used),
                    missing_discovered_urls=sorted(missing - served.keys()), files=inventory)
    manifest['seal_sha256'] = sha256(encoded(manifest))
    (output / MANIFEST).write_bytes(encoded(manifest) + b'\n')
    SealedFixture(output, sha256((output / MANIFEST).read_bytes()))
    return manifest


class SealedFixture:
    """Validated shared responses for ReplayCDP.lookup_response/replay_headers.

    Pin expected_manifest_sha256 in a run plan. Call validate() again after a
    native run to reject cache mutation. The helper never performs network I/O.
    """
    def __init__(self, root, expected_manifest_sha256=None):
        self.root = Path(root).resolve()
        raw = (self.root / MANIFEST).read_bytes()
        if expected_manifest_sha256 is not None and sha256(raw) != expected_manifest_sha256:
            raise ValueError('Sealed manifest SHA256 mismatch')
        self.manifest = json.loads(raw)
        payload = dict(self.manifest)
        seal = payload.pop('seal_sha256')
        if self.manifest.get('schema') != 1 or sha256(encoded(payload)) != seal:
            raise ValueError('Invalid sealed manifest')
        self.manifest_sha256 = sha256(raw)
        self.responses = {row['url']: row for row in self.manifest['responses']}
        if len(self.responses) != len(self.manifest['responses']):
            raise ValueError('Duplicate response URL in manifest')
        self.validate()

    def checked_path(self, relative):
        path = self.root / relative
        if Path(relative).is_absolute() or '..' in Path(relative).parts or path.is_symlink():
            raise ValueError('Unsafe manifest path')
        if self.root not in path.resolve().parents:
            raise ValueError('Manifest path leaves fixture')
        return path

    def validate(self):
        if sha256((self.root / MANIFEST).read_bytes()) != self.manifest_sha256:
            raise ValueError('Sealed manifest changed')
        expected = {row['path']: row for row in self.manifest['files']}
        actual = set()
        for path in self.root.rglob('*'):
            if path.is_symlink():
                raise ValueError('Sealed fixture contains a symlink')
            if path.is_file() and path != self.root / MANIFEST:
                actual.add(path.relative_to(self.root).as_posix())
        if actual != set(expected):
            raise ValueError('Sealed fixture file inventory changed')
        for relative, row in expected.items():
            body = self.checked_path(relative).read_bytes()
            if len(body) != row['bytes'] or sha256(body) != row['sha256']:
                raise ValueError('Sealed fixture file changed: ' + relative)

    def lookup_response(self, url, resource_type):
        row = self.responses.get(url)
        if row is None or (resource_type == 'Document' and not row['document']):
            return None
        relative = ('pages/' if resource_type == 'Document' else 'resources/') + sha256(url.encode())
        path = self.checked_path(relative)
        body = path.read_bytes()
        if len(body) != row['bytes'] or sha256(body) != row['sha256']:
            raise ValueError('Sealed response body changed: ' + url)
        expected = {'.url': url.encode(), '.headers.json': encoded(row['headers']),
                    '.status': b'200', '.content-type': row['mime'].encode()}
        for suffix, contents in expected.items():
            if self.checked_path(relative + suffix).read_bytes() != contents:
                raise ValueError('Sealed response metadata changed: ' + url)
        return body, row['mime'], path

    def replay_headers(self, body, mime, path):
        url = self.checked_path(str(Path(path).relative_to(self.root)) + '.url').read_text()
        row = self.responses[url]
        if self.lookup_response(url, 'Other') != (body, mime, self.root / 'resources' / sha256(url.encode())):
            raise ValueError('Replay response does not match sealed fixture')
        return [dict(header) for header in row['headers']]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--replay-result', action='append', default=[], type=Path)
    parser.add_argument('--expected-source-sha256', required=True)
    parser.add_argument('--url', default=URL)
    args = parser.parse_args()
    manifest = seal_fixture(args.source, args.output, args.replay_result,
                            args.expected_source_sha256, args.url)
    print(json.dumps(dict(output=str(args.output), source_sha256=manifest['source']['sha256'],
                          original_bodies=len(manifest['source']['files']),
                          served_urls=len(manifest['responses']),
                          unresolved_bodies=len(manifest['unresolved_source_paths']),
                          manifest_sha256=sha256((args.output / MANIFEST).read_bytes())), indent=2))


if __name__ == '__main__':
    main()
