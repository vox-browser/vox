import hashlib
import io
import json
from pathlib import Path
import tarfile
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from browser_input_evidence import identity, preserve_replay_inputs, verify_preservation_identity


class BrowserInputEvidenceTests(unittest.TestCase):
    def fixture(self, root):
        source = root / 'replay'
        (source / 'bodies').mkdir(parents=True)
        payload = b'original archived response'
        sha = hashlib.sha256(payload).hexdigest()
        body = source / 'bodies' / sha
        body.write_bytes(payload)
        entry = dict(status=200, headers=[dict(name='content-type', value='text/plain')],
                     sha256=sha, bytes=len(payload))
        manifest = dict(version=1, sealed_unix=123, url='https://example.test/',
                        responses={'https://example.test/': entry,
                                   'https://example.test/shared': dict(entry)})
        (source / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        references = {}
        for engine in ['vox', 'brave']:
            path = root / (engine + '.png')
            path.write_bytes((engine + ' reference bytes').encode())
            references[engine] = path
        return source, body, references, root / 'durable' / 'inputs.tar.gz'

    def test_round_trip_keeps_exact_manifest_bodies_and_reference_encodings(self):
        with TemporaryDirectory() as directory:
            source, body, references, output = self.fixture(Path(directory))
            (source / 'unrelated-tool.py').write_text('must not be copied')
            receipt = preserve_replay_inputs(source, references, output)
            with tarfile.open(output) as archive:
                names = archive.getnames()
                self.assertEqual(set(names), {'INPUTS.json', 'replay/manifest.json',
                    'replay/bodies/' + body.name, 'references/vox.png', 'references/brave.png'})
                for name, path in [('replay/manifest.json', source / 'manifest.json'),
                                   ('replay/bodies/' + body.name, body),
                                   ('references/vox.png', references['vox']),
                                   ('references/brave.png', references['brave'])]:
                    self.assertEqual(archive.extractfile(name).read(), path.read_bytes())
                index = json.load(archive.extractfile('INPUTS.json'))
                self.assertEqual(index['version'], 1)
                self.assertEqual(index['files']['references/vox.png'], identity(references['vox']))
            self.assertEqual(receipt['sha256'], identity(output)['sha256'])
            self.assertTrue(receipt['round_trip_verified'])
            self.assertFalse(receipt['reused'])
            self.assertEqual(receipt['members'], 5)

    def test_existing_matching_archive_is_verified_without_rewriting(self):
        with TemporaryDirectory() as directory:
            source, _, references, output = self.fixture(Path(directory))
            first = preserve_replay_inputs(source, references, output)
            before = output.stat().st_mtime_ns
            second = preserve_replay_inputs(source, references, output)
            self.assertTrue(second['reused'])
            self.assertEqual(first['sha256'], second['sha256'])
            self.assertEqual(before, output.stat().st_mtime_ns)

    def test_existing_archive_does_not_hide_changed_reference_pixels(self):
        with TemporaryDirectory() as directory:
            source, _, references, output = self.fixture(Path(directory))
            preserve_replay_inputs(source, references, output)
            original = output.read_bytes()
            previous = references['vox'].read_bytes()
            references['vox'].write_bytes(b'X' + previous[1:])
            with self.assertRaisesRegex(ValueError, 'Preserved replay'):
                preserve_replay_inputs(source, references, output)
            self.assertEqual(output.read_bytes(), original)

    def test_missing_or_corrupt_body_and_missing_reference_never_publish(self):
        for failure in ['missing-body', 'corrupt-body', 'missing-reference']:
            with self.subTest(failure=failure), TemporaryDirectory() as directory:
                source, body, references, output = self.fixture(Path(directory))
                if failure == 'missing-body':
                    body.unlink()
                elif failure == 'corrupt-body':
                    body.write_bytes(b'corrupt archived response')
                else:
                    references['brave'].unlink()
                with self.assertRaises((ValueError, FileNotFoundError)):
                    preserve_replay_inputs(source, references, output)
                self.assertFalse(output.exists())

    def test_input_directory_and_reference_cannot_be_archive_destinations(self):
        with TemporaryDirectory() as directory:
            source, _, references, _ = self.fixture(Path(directory))
            reference = references['vox'].read_bytes()
            for output in [source, source / 'saved.tar.gz', references['vox']]:
                with self.subTest(output=output), self.assertRaises(ValueError):
                    preserve_replay_inputs(source, references, output)
            self.assertEqual(references['vox'].read_bytes(), reference)

    def test_mutation_during_archiving_aborts_and_removes_temporary_output(self):
        with TemporaryDirectory() as directory:
            source, _, references, output = self.fixture(Path(directory))
            addfile = tarfile.TarFile.addfile

            def mutate(archive, member, fileobj=None):
                result = addfile(archive, member, fileobj)
                if member.name == 'INPUTS.json':
                    references['vox'].write_bytes(b'other reference bytes')
                return result

            with patch.object(tarfile.TarFile, 'addfile', mutate), self.assertRaisesRegex(
                    ValueError, 'Preserved replay|Replay input changed'):
                preserve_replay_inputs(source, references, output)
            self.assertFalse(output.exists())
            self.assertEqual(list(output.parent.iterdir()), [])

    def test_changed_source_or_preserved_archive_cannot_be_pinned_as_valid(self):
        with TemporaryDirectory() as directory:
            source, body, references, output = self.fixture(Path(directory))
            receipt = preserve_replay_inputs(source, references, output)
            pinned = {path: identity(path) for path in receipt['files']}
            pinned[receipt['path']] = identity(output)
            verify_preservation_identity(receipt, pinned)
            for path in [str(body.resolve()), receipt['path']]:
                changed = dict(pinned)
                changed[path] = dict(bytes=0, sha256='0' * 64)
                with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'after preservation'):
                    verify_preservation_identity(receipt, changed)

    def test_reference_free_diagnostic_preserves_replay_without_inventing_references(self):
        with TemporaryDirectory() as directory:
            source, _, _, output = self.fixture(Path(directory))
            receipt = preserve_replay_inputs(source, {}, output)
            self.assertEqual(receipt['members'], 3)
            with tarfile.open(output) as archive:
                self.assertFalse(any(name.startswith('references/') for name in archive.getnames()))

    def test_unexpected_archive_members_and_links_are_rejected(self):
        for kind in ['extra', 'symlink', 'duplicate']:
            with self.subTest(kind=kind), TemporaryDirectory() as directory:
                source, _, references, output = self.fixture(Path(directory))
                preserve_replay_inputs(source, references, output)
                with tarfile.open(output) as archive:
                    contents = [(member.name, archive.extractfile(member).read()) for member in archive]
                with tarfile.open(output, 'w:gz') as archive:
                    for name, data in contents:
                        member = tarfile.TarInfo(name)
                        if kind == 'symlink' and name == 'INPUTS.json':
                            member.type = tarfile.SYMTYPE
                            member.linkname = '/outside'
                            archive.addfile(member)
                            continue
                        member.size = len(data)
                        archive.addfile(member, io.BytesIO(data))
                    if kind != 'symlink':
                        archive.addfile(tarfile.TarInfo('extra' if kind == 'extra' else 'INPUTS.json'))
                tampered = output.read_bytes()
                with self.assertRaisesRegex(ValueError, 'Preserved replay'):
                    preserve_replay_inputs(source, references, output)
                self.assertEqual(tampered, output.read_bytes())

    def test_symlinked_body_is_rejected(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source, body, references, output = self.fixture(root)
            backing = root / 'body'
            body.rename(backing)
            body.symlink_to(backing)
            with self.assertRaisesRegex(ValueError, 'regular source files'):
                preserve_replay_inputs(source, references, output)
            self.assertFalse(output.exists())

    def test_concurrent_writer_is_never_overwritten(self):
        with TemporaryDirectory() as directory:
            source, _, references, output = self.fixture(Path(directory))

            def concurrent_writer(temporary, destination):
                Path(destination).write_bytes(b'concurrent evidence')
                raise FileExistsError('Another writer published first')

            with patch('browser_input_evidence.os.link', side_effect=concurrent_writer), self.assertRaises(
                    FileExistsError):
                preserve_replay_inputs(source, references, output)
            self.assertEqual(output.read_bytes(), b'concurrent evidence')
            self.assertEqual(list(output.parent.iterdir()), [output])


if __name__ == '__main__':
    unittest.main()
