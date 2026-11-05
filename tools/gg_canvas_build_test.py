from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from gg_canvas_build import has_gg_canvas


class GgCanvasBuildTest(unittest.TestCase):
    def test_uses_active_library_instead_of_the_compiler_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            library = root / 'active/vlib'
            (library / 'gg/canvas').mkdir(parents=True)
            with patch('gg_canvas_build.compiler_vlib', return_value=library) as resolve:
                self.assertTrue(has_gg_canvas('/moved/compiler/v'))
            self.assertEqual(resolve.call_args.args[0], '/moved/compiler/v')

    def test_standard_compiler_does_not_enable_the_optional_adapters(self):
        with tempfile.TemporaryDirectory() as directory:
            library = Path(directory) / 'vlib'
            (library / 'gg').mkdir(parents=True)
            with patch('gg_canvas_build.compiler_vlib', return_value=library):
                self.assertFalse(has_gg_canvas('/standard/v'))

    def test_compiler_without_root_subcommand_uses_the_existing_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            library = root / 'selected/vlib'
            (library / 'gg/canvas').mkdir(parents=True)
            compiler = root / 'v'
            compiler.write_text(f'''#!{sys.executable}
import sys
from pathlib import Path
assert sys.argv[1:4] == ['-memory-limit', '10G', 'run'], sys.argv
assert 'println(@VEXEROOT)' in Path(sys.argv[4]).read_text()
print({str(library.parent)!r})
''')
            compiler.chmod(0o755)
            self.assertTrue(has_gg_canvas(str(compiler)))


if __name__ == '__main__':
    unittest.main()
