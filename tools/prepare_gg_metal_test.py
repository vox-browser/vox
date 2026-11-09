from pathlib import Path
import tempfile
import unittest

from prepare_gg_metal import patch_header, prepare_sokol_metal


HEADER = '''prefix
_SOKOL_PRIVATE bool _sg_v_mtl_transfer(void) {
    _sg_v_mtl_flush();
    [cmd_buffer waitUntilCompleted];
    copyFromTexture:tex;
    _SG_OBJC_RELEASE(staging);
}
#endif

#if defined(_SOKOL_ANY_GL)
suffix
'''


class MetalReadbackStagingTests(unittest.TestCase):
    def test_preserves_existing_transfer_and_other_backends(self):
        result = patch_header(HEADER, Path('/test/helper.h'))
        self.assertIn('_sg_v_mtl_transfer_separate(void)', result)
        self.assertIn('#include "/test/helper.h"\n#endif', result)
        self.assertTrue(result.startswith('prefix\n'))
        self.assertTrue(result.endswith('#if defined(_SOKOL_ANY_GL)\nsuffix\n'))

    def test_rejects_ambiguous_or_changed_implementations(self):
        for value in [HEADER * 2, HEADER.replace('_sg_v_mtl_flush()', 'flush()'),
                      HEADER.replace('copyFromTexture:tex', 'copyFromTexture:other'),
                      HEADER.replace('#if defined(_SOKOL_ANY_GL)', '#if SOMETHING_NEW')]:
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                patch_header(value, Path('/test/helper.h'))

    def test_cache_preserves_upstream_and_rejects_modified_header(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            vlib, modules = root / 'vlib', root / 'modules'
            (root / 'thirdparty/sokol').mkdir(parents=True)
            (vlib / 'sokol/c').mkdir(parents=True)
            source = root / 'thirdparty/sokol/sokol_gfx.h'
            source.write_text(HEADER)
            declaration = vlib / 'sokol/c/declaration.c.v'
            original = 'module c\n#include "sokol_gfx.h"\n'
            declaration.write_text(original)
            (vlib / 'sokol/c/other.h').write_text('unchanged')
            staged = prepare_sokol_metal(modules, vlib, root / 'cache')
            self.assertEqual(source.read_text(), HEADER)
            self.assertEqual(declaration.read_text(), original)
            self.assertIn(str(staged / 'sokol_gfx.h'), (modules / 'sokol/c/declaration.c.v').read_text())
            self.assertEqual((modules / 'sokol/c/other.h').resolve(), vlib / 'sokol/c/other.h')
            self.assertEqual(prepare_sokol_metal(modules, vlib, root / 'cache'), staged)
            (staged / 'sokol_gfx.h').write_text('modified')
            with self.assertRaisesRegex(RuntimeError, 'Modified staged'):
                prepare_sokol_metal(modules, vlib, root / 'cache')
            self.assertEqual(source.read_text(), HEADER)
            self.assertEqual(declaration.read_text(), original)


if __name__ == '__main__':
    unittest.main()
