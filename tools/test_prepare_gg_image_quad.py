import json
import tempfile
import unittest
from pathlib import Path

from prepare_gg_image import prepare_image_quad


class ImageQuadStagingTests(unittest.TestCase):
    def test_repairs_coordinate_selection_without_changing_texture_wrapping(self):
        operation = json.loads((Path(__file__).parent / 'buildtools/gg_patches.json').read_text())['prepare_gg_image_quad'][0]
        with tempfile.TemporaryDirectory() as directory:
            canvas = Path(directory)
            surface = canvas / operation['file']
            surface.write_text(operation['old'])
            prepare_image_quad(canvas)
            self.assertEqual(surface.read_text(), operation['new'])
            prepare_image_quad(canvas)
            self.assertEqual(surface.read_text(), operation['new'])
            surface.write_text(operation['old'])
            prepare_image_quad(canvas)
            self.assertEqual(surface.read_text(), operation['new'])

    def test_leaves_older_surface_without_coordinate_adapter_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            canvas = Path(directory)
            surface = canvas / 'gpu_surface.v'
            surface.write_text('// older GPU surface\n')
            prepare_image_quad(canvas)
            self.assertEqual(surface.read_text(), '// older GPU surface\n')


if __name__ == '__main__':
    unittest.main()
