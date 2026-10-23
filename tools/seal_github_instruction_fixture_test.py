import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from seal_github_instruction_fixture import (
    MANIFEST, POLICY, SealedFixture, seal_fixture, sha256, source_fingerprint,
)


class SealedGitHubFixtureTests(unittest.TestCase):
    def put(self, source, category, url, body):
        path = source / category / sha256(url.encode())
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
        return path

    def prepare(self, root):
        source, output = root / 'source', root / 'sealed'
        url = 'https://github.com/vlang/v'
        css = 'https://assets.test/site.css?version=2'
        image = 'https://assets.test/icon.svg?color=red&size=1'
        imported = 'https://assets.test/nested.css'
        script = 'https://assets.test/runtime.js'
        page = (f'<base href="https://assets.test/"><link rel="stylesheet" href="{css}">'
                '<a href="missing">Missing</a>').encode()
        self.put(source, 'pages', url, page)
        self.put(source, 'resources', css,
                 b'@import "nested.css"; .icon{background:url("icon.svg?color=red&size=1")}')
        self.put(source, 'resources', imported, b'.red{color:red}')
        self.put(source, 'resources', image, b'<svg xmlns="http://www.w3.org/2000/svg"/>')
        script_path = self.put(source, 'resources', script, b'window.fixture=true;')
        self.put(source, 'resources', 'https://unused.test/unknown-key', b'unresolved original')
        fingerprint = source_fingerprint(source)
        ledger = root / 'replay.json'
        ledger.write_text(json.dumps(dict(cache_sha256=fingerprint['sha256'], requests=[
            dict(url=url, resource_type='Document', method='GET', action='replayed',
                 sha256=sha256(page)),
            dict(url=script, resource_type='Script', method='GET', action='replayed',
                 sha256=sha256(script_path.read_bytes())),
            dict(url='https://assets.test/post.js', resource_type='Script', method='POST',
                 action='blocked-missing-or-non-get'),
        ])))
        return source, output, ledger, fingerprint, url, css, image

    def test_seals_pinned_originals_and_recursive_references_for_both_engines(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, output, ledger, fingerprint, url, css, image = self.prepare(root)
            manual = hashlib.sha256()
            for path in sorted(p for p in source.rglob('*') if p.is_file()):
                manual.update(path.relative_to(source).as_posix().encode() + b'\0' + path.read_bytes())
            self.assertEqual(fingerprint['sha256'], manual.hexdigest())
            manifest = seal_fixture(source, output, [ledger], fingerprint['sha256'], url)
            self.assertEqual(manifest['metadata_policy'], POLICY)
            self.assertEqual(len(manifest['responses']), 5)
            self.assertEqual(len(manifest['unresolved_source_paths']), 1)
            self.assertEqual(len([p for p in (output / 'original').rglob('*') if p.is_file()]), 6)
            self.assertEqual(source_fingerprint(source), fingerprint)
            sealed = SealedFixture(output, sha256((output / MANIFEST).read_bytes()))
            body, mime, path = sealed.lookup_response(url, 'Document')
            key = sha256(url.encode())
            self.assertEqual(body, (output / 'resources' / key).read_bytes())
            self.assertEqual(mime, 'text/html; charset=utf-8')
            self.assertEqual(path, (output / 'pages' / key).resolve())
            headers = sealed.replay_headers(body, mime, path)
            self.assertEqual(headers, json.loads(Path(str(path) + '.headers.json').read_bytes()))
            self.assertIn(dict(name='Access-Control-Allow-Origin', value='*'), headers)
            self.assertIn(dict(name='Cache-Control', value='no-store'), headers)
            self.assertEqual(Path(str(path) + '.status').read_text(), '200')
            self.assertEqual(sealed.lookup_response(css, 'Stylesheet')[1], 'text/css')
            self.assertEqual(sealed.lookup_response(image, 'Image')[1], 'image/svg+xml')
            self.assertIsNone(sealed.lookup_response(image.split('?')[0], 'Image'))
            self.assertIsNone(sealed.lookup_response(image, 'Document'))
            self.assertIsNone(sealed.lookup_response('https://unused.test/unknown-key', 'Other'))
            self.assertIn('https://assets.test/missing', manifest['missing_discovered_urls'])
            self.assertFalse((output / 'resources' / sha256(b'https://unused.test/unknown-key')).exists())

    def test_rejects_source_or_ledger_mismatch_before_creating_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output, ledger, fingerprint, url, _, _ = self.prepare(Path(directory))
            with self.assertRaisesRegex(ValueError, 'Original fixture SHA256 mismatch'):
                seal_fixture(source, output, [ledger], '0' * 64, url)
            self.assertFalse(output.exists())
            row = json.loads(ledger.read_bytes())
            row['requests'][0]['sha256'] = '0' * 64
            ledger.write_text(json.dumps(row))
            with self.assertRaisesRegex(ValueError, 'ledger body SHA256 mismatch'):
                seal_fixture(source, output, [ledger], fingerprint['sha256'], url)
            self.assertFalse(output.exists())

    def test_output_is_exclusive_and_original_or_missing_input_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output, ledger, fingerprint, url, _, _ = self.prepare(Path(directory))
            with self.assertRaisesRegex(ValueError, 'outside the source'):
                seal_fixture(source, source / 'nested', [ledger], fingerprint['sha256'], url)
            with self.assertRaisesRegex(ValueError, 'Entry document is absent'):
                seal_fixture(source, output, [], fingerprint['sha256'], 'https://missing.test/')
            seal_fixture(source, output, [ledger], fingerprint['sha256'], url)
            before = (output / MANIFEST).read_bytes()
            with self.assertRaises(FileExistsError):
                seal_fixture(source, output, [ledger], fingerprint['sha256'], url)
            self.assertEqual((output / MANIFEST).read_bytes(), before)

    def test_lookup_and_validation_reject_tampering_or_missing_files(self):
        for mutation in ('body', 'headers', 'status', 'url', 'content-type', 'missing', 'extra',
                         'nested-manifest', 'manifest'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                source, output, ledger, fingerprint, url, css, _ = self.prepare(Path(directory))
                seal_fixture(source, output, [ledger], fingerprint['sha256'], url)
                sealed = SealedFixture(output)
                path = output / 'resources' / sha256(css.encode())
                if mutation == 'body':
                    path.write_bytes(b'tampered')
                elif mutation in ('headers', 'status', 'url', 'content-type'):
                    suffix = '.headers.json' if mutation == 'headers' else '.' + mutation
                    Path(str(path) + suffix).write_bytes(b'tampered')
                elif mutation == 'missing':
                    path.unlink()
                elif mutation == 'extra':
                    (output / 'extra').write_bytes(b'unpinned')
                elif mutation == 'nested-manifest':
                    (output / 'extra').mkdir()
                    (output / 'extra' / MANIFEST).write_bytes(b'unpinned')
                else:
                    (output / MANIFEST).write_bytes(b'{}')
                with self.assertRaises((ValueError, FileNotFoundError)):
                    sealed.validate()
                if mutation not in ('extra', 'nested-manifest', 'manifest'):
                    with self.assertRaises((ValueError, FileNotFoundError)):
                        sealed.lookup_response(css, 'Stylesheet')

    def test_a_later_document_request_promotes_a_known_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output, ledger, fingerprint, url, css, _ = self.prepare(Path(directory))
            result = json.loads(ledger.read_bytes())
            result['requests'] += [dict(url=css, resource_type=kind, method='GET', action='replayed')
                                   for kind in ('Other', 'Document')]
            ledger.write_text(json.dumps(result))
            seal_fixture(source, output, [ledger], fingerprint['sha256'], url)
            sealed = SealedFixture(output)
            self.assertEqual(sealed.lookup_response(css, 'Document')[0],
                             sealed.lookup_response(css, 'Other')[0])

    def test_rejects_manifest_pin_mismatch_and_source_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output, ledger, fingerprint, url, _, _ = self.prepare(Path(directory))
            seal_fixture(source, output, [ledger], fingerprint['sha256'], url)
            with self.assertRaisesRegex(ValueError, 'manifest SHA256 mismatch'):
                SealedFixture(output, '0' * 64)
            (source / 'linked').symlink_to(ledger)
            with self.assertRaisesRegex(ValueError, 'symlink'):
                source_fingerprint(source)


if __name__ == '__main__':
    unittest.main()
