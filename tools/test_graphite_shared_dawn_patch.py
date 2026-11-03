#!/usr/bin/env python3
"""Authenticate the pinned Dawn static-mesh and zero-slot initialization patch."""
import hashlib
from pathlib import Path
import tarfile
import tempfile
import unittest

from build_mac_graphite_dawn import REVISION, SHARED_PIXELS_INPUTS, prepare_shared_pixels_patch


class SharedDawnPatchTests(unittest.TestCase):
    def setUp(self):
        workspace = tempfile.TemporaryDirectory(prefix='vox-dawn-patch-test-')
        self.addCleanup(workspace.cleanup)
        self.root = Path(workspace.name)
        repo = Path(__file__).resolve().parents[1]
        self.archive = repo / 'Build/deps/skia-brave' / (REVISION + '.tar.gz')
        self.patch = repo / 'tools/skia_dawn_shared_pixels.patch'
        self.original = {}
        with tarfile.open(self.archive) as bundle:
            for name in SHARED_PIXELS_INPUTS:
                data = bundle.extractfile(f'skia-{REVISION}/{name}').read()
                self.original[name] = data
                target = self.root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)

    def test_installation_is_authenticated_and_idempotent(self):
        prepare_shared_pixels_patch(self.root, self.archive, self.patch)
        for name, values in SHARED_PIXELS_INPUTS.items():
            self.assertEqual(hashlib.sha256((self.root / name).read_bytes()).hexdigest(), values[1])
        prepare_shared_pixels_patch(self.root, self.archive, self.patch)

    def test_unknown_input_does_not_change_other_input(self):
        name = next(iter(self.original))
        (self.root / name).write_bytes(self.original[name] + b'// unknown\n')
        before = {n: (self.root / n).read_bytes() for n in self.original}
        with self.assertRaisesRegex(SystemExit, 'Unexpected or partially patched'):
            prepare_shared_pixels_patch(self.root, self.archive, self.patch)
        self.assertEqual(before, {n: (self.root / n).read_bytes() for n in before})

    def test_corrupted_patch_leaves_both_sources_unchanged(self):
        patch = self.root / 'modified.patch'
        data = self.patch.read_text()
        corrupted = data.replace('Tiny immutable meshes', 'Unexpected immutable meshes')
        self.assertNotEqual(data, corrupted)
        patch.write_text(corrupted)
        with self.assertRaisesRegex(SystemExit, 'Unexpected patched'):
            prepare_shared_pixels_patch(self.root, self.archive, patch)
        self.assertEqual(self.original, {n: (self.root / n).read_bytes() for n in self.original})

    def test_partial_installation_is_rejected(self):
        prepare_shared_pixels_patch(self.root, self.archive, self.patch)
        name = next(iter(self.original))
        (self.root / name).write_bytes(self.original[name])
        with self.assertRaisesRegex(SystemExit, 'Unexpected or partially patched'):
            prepare_shared_pixels_patch(self.root, self.archive, self.patch)


if __name__ == '__main__':
    unittest.main()
