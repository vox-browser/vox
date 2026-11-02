import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from localize_bundle_rpaths import localize


@unittest.skipUnless(sys.platform == 'darwin', 'Mach-O packaging requires macOS')
class BundleRuntimePathsTests(unittest.TestCase):
    def fixture(self, root, bundle_fallback=True, extra_rpath=None, canonical=False):
        shared = root / ('Build/v' if canonical else 'shared build')
        bundle = root / 'Vox.app/Contents/MacOS'
        shared.mkdir(parents=True)
        bundle.mkdir(parents=True)
        source, main = root / 'helper.c', root / 'main.c'
        for folder, value in [(shared, 17), (bundle, 29)]:
            source.write_text(f'int fixture_value(void) {{ return {value}; }}\n')
            subprocess.run(['clang', '-dynamiclib', str(source),
                            '-Wl,-install_name,@rpath/libFixture.dylib',
                            '-o', str(folder / 'libFixture.dylib')], check=True)
        main.write_text('#include <stdio.h>\nint fixture_value(void);\n'
                        'int main(void) { printf("%d\\n", fixture_value()); return 0; }\n')
        executable = bundle / 'fixture'
        command = ['clang', str(main), '-L' + str(shared), '-lFixture',
                   '-Wl,-rpath,' + str(shared), '-o', str(executable)]
        if bundle_fallback:
            command.append('-Wl,-rpath,@executable_path')
        if extra_rpath is not None:
            command.append('-Wl,-rpath,' + str(extra_rpath))
        subprocess.run(command, check=True)
        return executable, shared

    def run_fixture(self, executable):
        environment = {k: v for k, v in os.environ.items() if not k.startswith('DYLD_')}
        return subprocess.check_output([str(executable)], env=environment, text=True).strip()

    def test_packaged_app_uses_its_own_runtime_and_localization_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable, shared = self.fixture(Path(temporary))
            self.assertEqual(self.run_fixture(executable), '17')
            self.assertEqual(localize(executable, shared), [str(shared)])
            subprocess.run(['codesign', '--force', '--sign', '-', str(executable)],
                           check=True, capture_output=True)
            self.assertEqual(self.run_fixture(executable), '29')
            # A replacement shared build cannot change the app's loaded code.
            (shared / 'libFixture.dylib').unlink()
            self.assertEqual(self.run_fixture(executable), '29')
            before = hashlib.sha256(executable.read_bytes()).hexdigest()
            self.assertEqual(localize(executable, shared), [])
            self.assertEqual(hashlib.sha256(executable.read_bytes()).hexdigest(), before)

    def test_missing_bundle_search_path_fails_before_modifying_the_executable(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable, shared = self.fixture(Path(temporary), False)
            before = hashlib.sha256(executable.read_bytes()).hexdigest()
            with self.assertRaises(RuntimeError):
                localize(executable, shared)
            self.assertEqual(hashlib.sha256(executable.read_bytes()).hexdigest(), before)
            self.assertEqual(self.run_fixture(executable), '17')

    def test_staged_build_removes_both_staging_and_canonical_runtime_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            staging = root / '.production-output'
            staging.mkdir()
            executable, shared = self.fixture(root, extra_rpath=staging, canonical=True)
            self.assertEqual(self.run_fixture(executable), '17')
            with patch('localize_bundle_rpaths.__file__', str(root / 'tools/localize_bundle_rpaths.py')):
                self.assertEqual(localize(executable, staging), [str(shared), str(staging)])
            subprocess.run(['codesign', '--force', '--sign', '-', str(executable)],
                           check=True, capture_output=True)
            self.assertEqual(self.run_fixture(executable), '29')
            before = hashlib.sha256(executable.read_bytes()).hexdigest()
            with patch('localize_bundle_rpaths.__file__', str(root / 'tools/localize_bundle_rpaths.py')):
                self.assertEqual(localize(executable, staging), [])
            self.assertEqual(hashlib.sha256(executable.read_bytes()).hexdigest(), before)


if __name__ == '__main__':
    unittest.main()
