import tempfile
import unittest
from pathlib import Path
from prepare_gg_yuv import prepare


class YuvStagingTests(unittest.TestCase):
    def test_partial_staging_repairs_each_half_and_remains_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            canvas = Path(directory)
            (canvas / 'shaders').mkdir()
            layer = canvas / 'gpu_layer.v'
            shader = canvas / 'shaders/paint_snippets.metal'
            original_layer = 'const image_uniform_size = 112\n\tout << u.color_transform.gamma\n\tout << 0\n\tout << 0\n\tout << 0\n'
            original_shader = 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n'
            layer.write_text(original_layer)
            shader.write_text(original_shader)
            prepare(canvas)
            expected = (layer.read_bytes(), shader.read_bytes())
            self.assertIn(b'yuv_rec601_limited', expected[0])
            self.assertIn(b'color_transform.yuv420_atlas', expected[0])
            self.assertIn(b'document_image_yuv_atlas_upload_supported', expected[0])
            self.assertIn(b'gammaParameters_7.z > 0.0f', expected[1])
            self.assertIn(b'gammaParameters_7.y > 0.0f', expected[1])
            for reset in [layer, shader]:
                reset.write_text(original_layer if reset == layer else original_shader)
                prepare(canvas)
                self.assertEqual((layer.read_bytes(), shader.read_bytes()), expected)
            prepare(canvas)
            self.assertEqual((layer.read_bytes(), shader.read_bytes()), expected)


if __name__ == '__main__':
    unittest.main()
