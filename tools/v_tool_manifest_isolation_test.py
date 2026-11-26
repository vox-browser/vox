"""Bootstrap tools must not overwrite a supervised compiler's manifests."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BootstrapManifestIsolation(unittest.TestCase):
    def test_bootstrap_drops_only_ambient_manifest_environment(self):
        with tempfile.TemporaryDirectory(prefix='vox-bootstrap-env-') as directory:
            folder = Path(directory)
            compiler = folder / 'compiler'
            probe = '''import json, os, sys

keys = ('V_MACOS_V3_SOURCE_MANIFEST', 'V_MACOS_V3_C_ERROR_DIR',
        'V_MACOS_V3_NO_FALLBACK', 'VOX_TEST_PRESERVED_VALUE')
print(json.dumps(dict(env={key: os.environ[key] for key in keys if key in os.environ},
                      args=sys.argv[1:])))
'''
            interpreter = '#!' + sys.executable + '\n'
            compiler.write_text(interpreter + probe + '''from pathlib import Path

output = Path(sys.argv[sys.argv.index('-o') + 1])
output.write_text(''' + repr(interpreter + probe) + ''')
output.chmod(0o755)
''')
            compiler.chmod(0o755)
            env = dict(os.environ, V_BIN=str(compiler),
                       V_MACOS_V3_SOURCE_MANIFEST='1',
                       V_MACOS_V3_C_ERROR_DIR=str(folder / 'supervised-receipt'),
                       VOX_TEST_PRESERVED_VALUE='preserved')
            result = subprocess.run(['sh', str(ROOT / 'tools/run_v_tool.sh'),
                                     'production_source_manifest', 'compile', '--component-dir',
                                     str(folder / 'supervised-receipt')], env=env,
                                    text=True, capture_output=True, check=True)
            compilation, execution = map(json.loads, result.stdout.splitlines())
            for observed in (compilation, execution):
                self.assertEqual(observed['env'], {
                    'VOX_TEST_PRESERVED_VALUE': 'preserved',
                    'V_MACOS_V3_NO_FALLBACK': '1',
                })
            self.assertIn('-memory-limit', compilation['args'])
            self.assertEqual(execution['args'], ['compile', '--component-dir',
                                                  str(folder / 'supervised-receipt')])


if __name__ == '__main__':
    unittest.main()
