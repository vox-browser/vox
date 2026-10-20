#!/usr/bin/env python3
"""Check the actual macOS allocator bootstrap, exec identity and caller policy."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class NativeAllocatorPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='vox-allocator-')
        cls.binary = Path(cls.temporary.name) / 'allocator policy'
        root = Path(__file__).resolve().parents[1]
        subprocess.run(['clang', '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror',
            str(root / 'tools/native_allocator_policy_test.c'), '-o', str(cls.binary)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def launch(self, policy=None, arguments=(), pass_fds=()):
        env = dict(os.environ)
        env.pop('MallocSpaceEfficient', None)
        if policy is not None:
            env['MallocSpaceEfficient'] = policy
        if pass_fds:
            env['VOX_ALLOCATOR_TEST_FD'] = str(pass_fds[0])
        process = subprocess.Popen([str(self.binary), *arguments], env=env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, pass_fds=pass_fds)
        stdout, stderr = process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(stderr, '')
        lines = stdout.splitlines()
        self.assertEqual(lines[0], f'pid={process.pid}')
        self.assertEqual(lines[2:], [f'argument={value}' for value in arguments])
        return lines[1]

    def test_default_restarts_with_compact_allocator_and_preserves_arguments(self):
        self.assertEqual(self.launch(arguments=['', 'space and "quotes"', 'λ 日本語',
            '--vox-adblock-worker-v1']), 'policy=1')

    def test_explicit_settings_keep_precedence(self):
        for policy in ['0', '1', '']:
            with self.subTest(policy=policy):
                self.assertEqual(self.launch(policy=policy), f'policy={policy}')

    def test_inherited_descriptors_survive_the_restart(self):
        read_fd, write_fd = os.pipe()
        try:
            self.assertEqual(self.launch(pass_fds=(write_fd,)), 'policy=1')
            os.close(write_fd)
            write_fd = -1
            self.assertEqual(os.read(read_fd, 1024), b'inherited descriptor\n')
        finally:
            os.close(read_fd)
            if write_fd != -1:
                os.close(write_fd)


if __name__ == '__main__':
    unittest.main()
