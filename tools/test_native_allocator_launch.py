"""Exercise the production allocator policy through actual LaunchServices launches."""
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import uuid


@unittest.skipUnless(sys.platform == 'darwin', 'macOS LaunchServices allocator policy')
class AllocatorLaunchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='vox-allocator-launch-')
        cls.output = Path(cls.temporary.name)
        cls.root = Path(__file__).resolve().parents[1]
        cls.production_info = plistlib.loads((cls.root / 'packaging/Info.plist').read_bytes())
        cls.binary = cls.output / 'probe'
        subprocess.run(['clang', '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror',
                        str(cls.root / 'tools/native_allocator_launch_test.c'),
                        '-o', str(cls.binary)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def launch(self, policy=None, configured=True):
        identity = uuid.uuid4().hex
        app = self.output / (identity + '.app')
        executable = app / 'Contents/MacOS/probe'
        executable.parent.mkdir(parents=True)
        # This is an independent native policy fixture, never a browser copy.
        executable.write_bytes(self.binary.read_bytes())
        executable.chmod(0o755)
        info = dict(self.production_info, CFBundleExecutable='probe',
                    CFBundleIdentifier='org.vox.allocator-test.' + identity)
        if not configured:
            info.pop('LSEnvironment', None)
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        stdout = self.output / (identity + '.stdout')
        stderr = self.output / (identity + '.stderr')
        command = ['open', '-n', '-g', '-W', '-a', str(app),
                   '--stdout', str(stdout), '--stderr', str(stderr)]
        if policy is not None:
            command += ['--env', 'MallocSpaceEfficient=' + policy]
        environment = {k: v for k, v in os.environ.items() if k != 'MallocSpaceEfficient'}
        completed = subprocess.run(command, env=environment, capture_output=True,
                                   text=True, timeout=15)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        lines = stdout.read_text().splitlines()
        self.assertEqual(len(lines), 2)
        self.assertGreater(int(lines[1].removeprefix('pid=')), 0)
        return lines[0], stderr.read_text()

    def test_bundle_selects_compact_allocator_before_library_initialization(self):
        self.assertEqual(self.production_info['LSEnvironment']['MallocSpaceEfficient'], '1')
        self.assertEqual(self.launch(), ('policy=1', ''))

    def test_launch_overrides_preserve_the_callers_allocator_policy(self):
        for policy in ('0', '1', ''):
            with self.subTest(policy=policy):
                self.assertEqual(self.launch(policy), ('policy=' + policy, ''))

    def test_unconfigured_launch_retains_the_direct_execution_fallback(self):
        self.assertEqual(self.launch(configured=False), ('policy=1', 'allocator restart\n'))


if __name__ == '__main__':
    unittest.main()
