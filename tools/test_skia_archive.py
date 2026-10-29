#!/usr/bin/env python3
"""Exercise the shared Skia archive extraction used by both Metal builders."""
import io
from pathlib import Path
import tarfile
import tempfile
import unittest

from build_mac_graphite import REVISION, extract_skia_archive


ROOT = f'skia-{REVISION}'


class SkiaArchiveTests(unittest.TestCase):
    def archive(self, directory, members):
        archive = directory / 'source.tar.gz'
        with tarfile.open(archive, 'w:gz') as bundle:
            for name, kind, value in members:
                member = tarfile.TarInfo(name)
                if kind == 'file':
                    data = value.encode()
                    member.size = len(data)
                    bundle.addfile(member, io.BytesIO(data))
                else:
                    member.type = tarfile.SYMTYPE if kind == 'symlink' else tarfile.LNKTYPE
                    member.linkname = value
                    bundle.addfile(member)
        return archive

    def test_pinned_fontations_link_and_internal_hardlink(self):
        # The pinned Skia archive contains precisely this relative Cargo link.
        manifest = f'{ROOT}/bazel/external/fontations/Cargo.toml'
        cargo = f'{ROOT}/src/ports/fontations/Cargo.toml'
        alias = f'{ROOT}/manifest-copy'
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive = self.archive(directory, [
                (manifest, 'file', '[package]\nname = "fontations"\n'),
                (cargo, 'symlink', '../../../bazel/external/fontations/Cargo.toml'),
                (alias, 'hardlink', manifest),
            ])
            output = directory / 'extracted'
            extract_skia_archive(archive, output)
            self.assertTrue((output / cargo).is_symlink())
            self.assertEqual((output / cargo).read_bytes(), (output / manifest).read_bytes())
            self.assertEqual((output / alias).stat().st_ino, (output / manifest).stat().st_ino)

    def assert_rejected(self, member):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            # Validate the whole archive before writing even its first good file.
            archive = self.archive(directory, [(f'{ROOT}/good', 'file', 'good'), member])
            output = directory / 'extracted'
            with self.assertRaises(SystemExit):
                extract_skia_archive(archive, output)
            self.assertFalse(output.exists())

    def test_rejects_members_outside_expected_root(self):
        for name in ['', '/absolute', 'other/file', f'{ROOT}/../outside']:
            with self.subTest(name=name):
                self.assert_rejected((name, 'file', 'unexpected'))

    def test_rejects_symlinks_outside_expected_root(self):
        for target in ['/absolute', '../../outside', '../other/file']:
            with self.subTest(target=target):
                self.assert_rejected((f'{ROOT}/link', 'symlink', target))

    def test_rejects_hardlinks_outside_expected_root(self):
        for target in ['/absolute', 'other/file', f'{ROOT}/../outside']:
            with self.subTest(target=target):
                self.assert_rejected((f'{ROOT}/link', 'hardlink', target))


if __name__ == '__main__':
    unittest.main()
