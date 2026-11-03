#!/usr/bin/env python3
"""Check authenticated installation of the Metal static-mesh upload patch."""
import tarfile
import tempfile
import unittest
from pathlib import Path

from build_mac_graphite import (HOST_STATIC_SOURCE, REVISION,
                                prepare_host_static_patch)


class HostStaticPatchTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory(prefix='vox-host-static-test-')
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        repo = Path(__file__).resolve().parents[1]
        self.archive = repo / 'Build/deps/skia-brave' / (REVISION + '.tar.gz')
        self.patch = repo / 'tools/skia_metal_host_static.patch'
        with tarfile.open(self.archive) as bundle:
            self.original = bundle.extractfile(f'skia-{REVISION}/{HOST_STATIC_SOURCE}').read()
        self.target = self.root / HOST_STATIC_SOURCE
        self.target.parent.mkdir(parents=True)
        self.target.write_bytes(self.original)

    def test_authenticated_install_is_idempotent(self):
        prepare_host_static_patch(self.root, self.archive, self.patch)
        installed = self.target.read_bytes()
        self.assertNotEqual(installed, self.original)
        prepare_host_static_patch(self.root, self.archive, self.patch)
        self.assertEqual(self.target.read_bytes(), installed)

    def test_unknown_source_is_rejected_without_modification(self):
        unknown = self.original + b'\n// unrecognized local change\n'
        self.target.write_bytes(unknown)
        with self.assertRaisesRegex(SystemExit, 'Unexpected Skia static-buffer source'):
            prepare_host_static_patch(self.root, self.archive, self.patch)
        self.assertEqual(self.target.read_bytes(), unknown)

    def test_modified_patch_is_rejected_before_installation(self):
        corrupted = self.root / 'corrupted.patch'
        contents = self.patch.read_text()
        modified = contents.replace('less than 6 KiB', 'less than 7 KiB')
        self.assertNotEqual(contents, modified)
        corrupted.write_text(modified)
        with self.assertRaisesRegex(SystemExit, 'Unexpected patched Skia static-buffer source'):
            prepare_host_static_patch(self.root, self.archive, corrupted)
        self.assertEqual(self.target.read_bytes(), self.original)


if __name__ == '__main__':
    unittest.main()
