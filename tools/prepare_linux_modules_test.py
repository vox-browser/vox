import tempfile
import unittest
from pathlib import Path

from prepare_linux_modules import stage_module


class LinuxModuleStagingTest(unittest.TestCase):
    def test_sources_assets_refresh_and_compiler_is_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / 'compiler/gg', root / 'modules/gg'
            (source / 'render').mkdir(parents=True)
            original = 'usize(count) * usize(sizeof(Vertex))\nu64(usize(voidptr(context)))'
            (source / 'render/context.v').write_text(original)
            (source / 'shader.h').write_text('shader asset')
            stage_module(source, target, 'gg')
            patched = (target / 'render/context.v').read_text()
            self.assertIn('uint(count) * uint(sizeof(Vertex))', patched)
            self.assertIn('u64(voidptr(context))', patched)
            self.assertEqual((target / 'shader.h').read_text(), 'shader asset')
            self.assertEqual((source / 'render/context.v').read_text(), original)
            stage_module(source, target, 'gg')
            self.assertEqual((target / 'render/context.v').read_text(), patched)
            (source / 'shader.h').unlink()
            stage_module(source, target, 'gg')
            self.assertFalse((target / 'shader.h').is_symlink())

    def test_stbi_keeps_conditionally_used_os_import(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'stbi', Path(directory) / 'staged'
            source.mkdir()
            (source / 'stbi.c.v').write_text('import os\n$if trace_stbi_allocations ? { os.args }')
            stage_module(source, target, 'stbi')
            self.assertIn('import os as _\n', (target / 'stbi.c.v').read_text())

    def test_tls_keeps_borrowed_write_buffer(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'openssl', Path(directory) / 'staged'
            source.mkdir()
            original = 'unsafe {\n\tmut ptr_base := bytes\n\tptr := ptr_base + offset\n}'
            (source / 'ssl_connection.c.v').write_text(original)
            stage_module(source, target, 'net/openssl')
            patched = (target / 'ssl_connection.c.v').read_text()
            self.assertTrue(patched.startswith('mut ptr_base := unsafe { bytes }\nunsafe {\n'))
            stage_module(source, target, 'net/openssl')
            self.assertEqual((target / 'ssl_connection.c.v').read_text(), patched)
            self.assertEqual((source / 'ssl_connection.c.v').read_text(), original)


if __name__ == '__main__':
    unittest.main()
