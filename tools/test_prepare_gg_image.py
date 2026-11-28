import json
import tempfile
import unittest
from pathlib import Path

from prepare_gg_image import prepare_opaque


class OpaqueImageStagingTests(unittest.TestCase):
    def test_each_file_repairs_independently_and_stays_idempotent(self):
        patches = json.loads((Path(__file__).parent / 'buildtools/gg_patches.json').read_text())
        operations = [patches[name][0] for name in
                      ['prepare_gg_opaque_layer', 'prepare_gg_opaque_surface']]
        with tempfile.TemporaryDirectory() as directory:
            canvas = Path(directory)
            for operation in operations:
                (canvas / operation['file']).write_text(operation['old'])
            prepare_opaque(canvas)
            expected = {operation['file']: operation['new'] for operation in operations}
            self.assertIn('layer.document_opaque && layer.mask_color.a == 1',
                          expected['gpu_surface.v'])
            self.assertIn('(shading != .image || image_opaque)', expected['gpu_surface.v'])
            for reset in operations:
                (canvas / reset['file']).write_text(reset['old'])
                prepare_opaque(canvas)
                self.assertEqual({name: (canvas / name).read_text() for name in expected}, expected)
            prepare_opaque(canvas)
            self.assertEqual({name: (canvas / name).read_text() for name in expected}, expected)


if __name__ == '__main__':
    unittest.main()
