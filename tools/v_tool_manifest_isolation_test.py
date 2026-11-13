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
            compiler.write_text('#!' + sys.executable + '\nimport json,os,sys\n'
                                'print(json.dumps(dict(env=dict(os.environ),args=sys.argv[1:])))\n')
            compiler.chmod(0o755)
            env = dict(os.environ, V_BIN=str(compiler),
                       V_MACOS_V3_SOURCE_MANIFEST='1',
                       V_MACOS_V3_C_ERROR_DIR=str(folder / 'supervised-receipt'),
                       VOX_TEST_PRESERVED_VALUE='preserved')
            result = subprocess.run(['sh', str(ROOT / 'tools/run_v_tool.sh'),
                                     'production_source_manifest', 'compile', '--component-dir',
                                     str(folder / 'supervised-receipt')], env=env,
                                    text=True, capture_output=True, check=True)
            observed = json.loads(result.stdout)
            self.assertNotIn('V_MACOS_V3_SOURCE_MANIFEST', observed['env'])
            self.assertNotIn('V_MACOS_V3_C_ERROR_DIR', observed['env'])
            self.assertEqual(observed['env']['VOX_TEST_PRESERVED_VALUE'], 'preserved')
            self.assertEqual(observed['env']['V_MACOS_V3_NO_FALLBACK'], '1')
            self.assertIn('-memory-limit', observed['args'])
            self.assertEqual(observed['args'][-3:], ['compile', '--component-dir',
                                                    str(folder / 'supervised-receipt')])


if __name__ == '__main__':
    unittest.main()
