import json
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
            original_layer = 'const image_uniform_size = 112\n\t\tfor row in 0 .. 3 { out << u.color_transform.gamut[column * 3 + row] }\n\tout << u.color_transform.gamma\n\tout << 0\n\tout << 0\n\tout << 0\n'
            patches = json.loads((Path(__file__).parent / 'buildtools/gg_patches.json').read_text())
            coordinates = patches['prepare_gg_yuv_coordinates']
            original_shader = coordinates[0]['old'] + '\n' + 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n'
            layer.write_text(original_layer)
            shader.write_text(original_shader)
            prepare(canvas)
            expected = (layer.read_bytes(), shader.read_bytes())
            self.assertIn(b'yuv_rec601_limited', expected[0])
            self.assertIn(b'color_transform.yuv420_atlas', expected[0])
            self.assertIn(b'document_image_yuv_atlas_upload_supported', expected[0])
            self.assertIn(b'gammaParameters_7.z > 0.0f', expected[1])
            self.assertIn(b'gammaParameters_7.y > 0.0f', expected[1])
            self.assertIn(b'color_transform.yuv_jpeg_full', expected[0])
            self.assertIn(b'document_image_jpeg_upload_supported', expected[0])
            self.assertIn(b'gammaParameters_7.w > 0.0f', expected[1])
            self.assertIn(b'float2 documentImageCoords', expected[1])
            self.assertIn(b'documentImageCoords * 0.5f', expected[1])
            for operation in coordinates:
                shader.write_text(shader.read_text().replace(operation['new'], operation['old'], 1))
                prepare(canvas)
                self.assertEqual((layer.read_bytes(), shader.read_bytes()), expected)
            self.assertIn(b'yuv_chroma_bounds[index]', expected[0])
            self.assertIn(b'float4 chromaBounds', expected[1])
            for operation in patches['prepare_gg_yuv_subset']:
                target = canvas / operation['file']
                target.write_text(target.read_text().replace(operation['new'], operation['old'], 1))
                prepare(canvas)
                self.assertEqual((layer.read_bytes(), shader.read_bytes()), expected)
            for reset in [layer, shader]:
                reset.write_text(original_layer if reset == layer else original_shader)
                prepare(canvas)
                self.assertEqual((layer.read_bytes(), shader.read_bytes()), expected)
            self.assertIn(b'float4 lumaBounds', expected[1])
            for operation in patches['prepare_gg_yuv_luma_subset']:
                shader.write_text(shader.read_text().replace(operation['new'], operation['old'], 1))
                prepare(canvas)
                self.assertEqual((layer.read_bytes(), shader.read_bytes()), expected)
            prepare(canvas)
            self.assertEqual((layer.read_bytes(), shader.read_bytes()), expected)


if __name__ == '__main__':
    unittest.main()
