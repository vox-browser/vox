"""Exercise dependency discovery without CMake/pkgconf (use a compiled V driver)."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(sys.platform == 'darwin', 'macOS build dependencies')
class MacOSBuildDependenciesTest(unittest.TestCase):
    def test_homebrew_prefix_with_spaces_and_no_package_tools(self):
        driver = str(Path(os.environ['VOX_BUILD_TOOLS_EXE']).resolve())
        with tempfile.TemporaryDirectory(prefix='vox-macos-deps-') as directory:
            root = Path(directory)
            sdk = root / 'custom brew' / 'libavif'
            (sdk / 'include/avif').mkdir(parents=True)
            (sdk / 'lib').mkdir()
            (sdk / 'include/avif/avif.h').write_text('')
            (sdk / 'lib/libavif.dylib').write_text('')
            tools = root / 'bin'
            tools.mkdir()
            brew = tools / 'brew'
            brew.write_text('#!/bin/sh\n[ "$1" = --prefix ] && [ "$2" = libavif ] || exit 2\nprintf "%s\\n" "$TEST_AVIF_PREFIX"\n')
            brew.chmod(0o755)
            for name in ['cmake', 'pkg-config', 'pkgconf']:
                path = tools / name
                path.write_text('#!/bin/sh\necho unexpected >> "$TEST_FORBIDDEN_LOG"\nexit 99\n')
                path.chmod(0o755)
            forbidden = root / 'forbidden.log'
            environment = dict(os.environ, PATH=str(tools) + ':/usr/bin:/bin',
                               TEST_AVIF_PREFIX=str(sdk), TEST_FORBIDDEN_LOG=str(forbidden))
            result = subprocess.run([driver, 'macos_dependency_prefix', 'libavif'],
                                    env=environment, text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout.strip(), str(sdk.resolve()))
            rejected = subprocess.run([driver, 'macos_dependency_prefix', 'unsupported'],
                                      env=environment, text=True, capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn('Unsupported macOS dependency', rejected.stderr)
            self.assertFalse(forbidden.exists())


if __name__ == '__main__':
    unittest.main()
