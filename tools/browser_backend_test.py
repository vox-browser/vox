from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from browser_backend import browser_backend


class BrowserBackendTests(unittest.TestCase):
    def test_manifest_controls_backend_without_accepting_compiler_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for backend in ('fastc', 'c'):
                (root / 'v.mod').write_text("Module {\n backend: '" + backend + "'\n}\n")
                result = subprocess.run([sys.executable, str(Path(__file__).with_name('browser_backend.py')),
                                         str(root)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), backend)
            for setting in ('', "backend: 'fastc -cc clang'", "backend: 'unknown'",
                            "backend: 'c'\nbackend: 'fastc'"):
                (root / 'v.mod').write_text('Module {\n' + setting + '\n}\n')
                with self.assertRaises(ValueError):
                    browser_backend(root)


if __name__ == '__main__':
    unittest.main()
