"""Input/publication regression sources; run after the current test hold lifts.

Supply a separately built helper through VOX_METAL_RECTANGLE_REPLAY_BINARY.
These rejection paths finish before creating a Metal device.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


BINARY = os.environ.get('VOX_METAL_RECTANGLE_REPLAY_BINARY')


@unittest.skipUnless(BINARY, 'requires the separately built Metal replay helper')
class SnapshotInputTests(unittest.TestCase):
    def invoke(self, source, output, *options):
        return subprocess.run([BINARY, str(source), str(output), *map(str, options)],
                              capture_output=True, text=True, timeout=10)

    def test_existing_sample_evidence_is_never_replaced(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'pixels.bgra'
            samples = root / 'samples.rgba32f'
            samples.write_bytes(b'keep sample evidence')
            result = self.invoke(root / 'missing-snapshot', output,
                                 '--samples-output', samples)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Sample output already exists', result.stderr)
            self.assertEqual(samples.read_bytes(), b'keep sample evidence')
            self.assertFalse(output.exists())

    def test_sample_and_pixel_outputs_cannot_alias(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'pixels.bgra'
            result = self.invoke(root / 'missing-snapshot', output,
                                 '--samples-output', output)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Sample and pixel outputs must differ', result.stderr)
            self.assertFalse(output.exists())

    def test_repeated_sample_output_option_declines_before_publication(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'pixels.bgra'
            samples = root / 'samples.rgba32f'
            result = self.invoke(root / 'missing-snapshot', output,
                                 '--samples-output', samples,
                                 '--samples-output', root / 'other.rgba32f')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Duplicate sample output option', result.stderr)
            self.assertFalse(output.exists())
            self.assertFalse(samples.exists())

    def test_corrupt_snapshot_cannot_publish_pixels(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'vertices.bin').write_bytes(b'changed!')
            (root / 'draw.json').write_text(json.dumps({'files': {'vertices.bin': {
                'size': 8, 'sha256': hashlib.sha256(b'original').hexdigest()}}}))
            output = root / 'pixels.bgra'
            result = self.invoke(root, output)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Snapshot input hash mismatch', result.stderr)
            self.assertFalse(output.exists())

    def test_existing_receipt_is_never_replaced(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'pixels.bgra'
            output.write_bytes(b'keep existing evidence')
            result = self.invoke(root / 'missing-snapshot', output)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Output already exists', result.stderr)
            self.assertEqual(output.read_bytes(), b'keep existing evidence')

    def test_manifest_cannot_escape_snapshot_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'snapshot'
            source.mkdir()
            (root / 'outside.bin').write_bytes(b'outside')
            (source / 'draw.json').write_text(json.dumps({'files': {'../outside.bin': {
                'size': 7, 'sha256': hashlib.sha256(b'outside').hexdigest()}}}))
            output = root / 'pixels.bgra'
            result = self.invoke(source, output)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Invalid snapshot filename', result.stderr)
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
