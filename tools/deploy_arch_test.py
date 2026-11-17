from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import deploy_arch as deploy


class ArchDeployTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-arch-deploy-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.source = self.root / 'Build/linux/vox'
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(b'ELF fixture with debug symbols')
        self.source.chmod(0o755)
        self.receipt = dict(exit=0, executable_sha256=deploy.sha256(self.source),
                            c_compile=dict(backend='c', mode='single', requested='single', v_prod=True))
        self.receipt_path = self.root / 'Build/linux/production-build/latest.json'
        self.receipt_path.parent.mkdir()
        self.receipt_path.write_text(json.dumps(self.receipt))
        packaging = self.root / 'packaging'
        packaging.mkdir()
        (packaging / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleShortVersionString='0.1.4')))
        (packaging / 'version.txt').write_text('0.1.4\n')
        for name in ('Vox.png', 'vox.desktop'):
            shutil.copyfile(deploy.ROOT / 'packaging' / name, packaging / name)
        for name in ('LICENSE', 'THIRD_PARTY_NOTICES.md'):
            shutil.copyfile(deploy.ROOT / name, self.root / name)
        self.output = self.root / 'output with spaces/vox-0.1.4-1-x86_64.pkg.tar.zst'
        self.commands = []
        self.failure = None
        self.owner = 'glibc'
        self.linked = '\tlibc.so.6 => /usr/lib/libc.so.6 (0x123)\n'
        self.environments = []
        self.package_identity = 'vox 0.1.4-1'
        self.corrupt_payload = False

    def fake_run(self, command, root, **kwargs):
        command = list(map(str, command))
        self.commands.append(command)
        self.environments.append(kwargs.get('env', {}))
        if self.failure and self.failure in command:
            raise subprocess.CalledProcessError(1, command)
        stdout = ''
        if command[0] == 'strip':
            Path(command[-1]).write_bytes(b'stripped ELF')
        elif command[:2] == ['readelf', '--dynamic']:
            stdout = ' 0x0000000000000001 (NEEDED) Shared library: [libc.so.6]\n'
        elif command[0] == 'ldd':
            stdout = self.linked
        elif command[:2] == ['pacman', '-Qqo']:
            stdout = self.owner
        elif command[:2] == ['pacman', '-Q']:
            stdout = 'glibc 2.42-1\nca-certificates 2025.10.18-1\nttf-dejavu 2.37-8\n'
        elif command[0] == 'makepkg':
            self.work = Path(command[command.index('--dir') + 1])
            self.pkgbuild = (self.work / 'PKGBUILD').read_text()
            (self.work / self.output.name).write_bytes(b'Arch archive fixture')
        elif command[:2] == ['pacman', '-Qp']:
            stdout = self.package_identity + '\n'
        elif command[0] == 'bsdtar':
            shutil.copytree(self.work / 'payload', command[-1], dirs_exist_ok=True, symlinks=True)
            if self.corrupt_payload:
                (Path(command[-1]) / 'usr/lib/vox/vox').write_bytes(b'changed package binary')
        elif command[-1] == '--headless-smoke':
            executable = Path(command[0])
            self.assertTrue(executable.is_symlink())
            self.assertEqual(executable.read_bytes(), b'stripped ELF')
            self.assertNotIn('VOX_PROXY', kwargs['env'])
        return subprocess.CompletedProcess(command, 0, stdout=stdout)

    def fake_guarded(self, command, root, work, name, limit_gib=12, **kwargs):
        self.fake_run(command, root, **kwargs)
        return dict(child_exit_code=0, reason='completed')

    def package(self, package_only=True):
        with patch.object(deploy, 'run', side_effect=self.fake_run), \
                patch.object(deploy, 'capture', side_effect=lambda command, root: self.fake_run(command, root).stdout.strip()), \
                patch.object(deploy, 'guarded', side_effect=self.fake_guarded), \
                patch.object(deploy.shutil, 'which', return_value='/usr/bin/tool'), \
                patch.object(deploy.os, 'geteuid', return_value=1000), \
                patch.object(deploy.platform, 'machine', return_value='x86_64'), \
                redirect_stdout(io.StringIO()):
            return deploy.deploy(self.root, self.output, package_only)

    def test_native_package_metadata_dependencies_and_smoked_payload(self):
        before = deploy.sha256(self.source)
        with patch.dict(os.environ, VOX_PROXY='http://invalid.example'):
            self.assertEqual(self.package(), self.output)
        self.assertEqual(deploy.sha256(self.source), before)
        self.assertIn('pkgver=0.1.4\npkgrel=1\n', self.pkgbuild)
        self.assertIn('arch=(x86_64)', self.pkgbuild)
        self.assertIn('depends=(ca-certificates glibc ttf-dejavu)', self.pkgbuild)
        self.assertIn("license=('GPL-3.0-or-later')", self.pkgbuild)
        manifest = json.loads(self.output.with_name(self.output.name + '.json').read_text())
        self.assertEqual(manifest['source_build'], self.receipt)
        self.assertEqual(manifest['package_sha256'], deploy.sha256(self.output))
        self.assertEqual(manifest['source_binaries_sha256'], {'vox': before})
        self.assertEqual(set(manifest['memory_reports']), {'create', 'extract', 'smoke'})
        self.assertFalse(any('rebuild_browser' in command for command in self.commands))
        self.assertEqual(len(list(self.output.parent.iterdir())), 2)

    def test_default_build_pins_prod_and_drops_inherited_build_overrides(self):
        with patch.dict(os.environ, VOX_BUILD_BACKEND='fastc', VOX_LINUX_CFLAGS='-O0',
                        PKGEXT='.pkg.tar.xz', CARCH='aarch64'):
            self.package(package_only=False)
        self.assertEqual(self.commands[0], ['sh', str(self.root / 'tools/run_v_tool.sh'),
            'rebuild_browser', '--build', '--backend', 'c', '--prod', '--no-parallel-cc'])
        self.assertNotIn('VOX_BUILD_BACKEND', self.environments[0])
        self.assertNotIn('VOX_LINUX_CFLAGS', self.environments[0])
        package_env = self.environments[next(i for i, command in enumerate(self.commands) if command[0] == 'makepkg')]
        self.assertEqual(package_env['PKGEXT'], '.pkg.tar.zst')
        self.assertEqual(package_env['CARCH'], 'x86_64')

    def test_unresolved_or_unowned_libraries_cannot_be_published(self):
        self.linked = '\tlibc.so.6 => not found\n'
        with self.assertRaisesRegex(RuntimeError, 'Unresolved runtime library'):
            self.package()
        self.linked = '\tlibc.so.6 => /usr/lib/libc.so.6 (0x123)\n'
        self.owner = 'not a package'
        with self.assertRaisesRegex(RuntimeError, 'Invalid runtime package owner'):
            self.package()
        self.assertFalse(self.output.exists())

    def test_failure_preserves_previous_output_and_cleans_all_staging(self):
        self.output.parent.mkdir()
        self.output.write_bytes(b'previous package')
        for failure in ('rebuild_browser', 'strip', 'readelf', 'makepkg', 'bsdtar', '--headless-smoke'):
            self.failure = failure
            with self.subTest(failure=failure), self.assertRaises(subprocess.CalledProcessError):
                self.package(package_only=failure != 'rebuild_browser')
            self.assertEqual(self.output.read_bytes(), b'previous package')
            self.assertEqual(list(self.output.parent.iterdir()), [self.output])

    def test_wrong_build_receipt_is_rejected(self):
        self.receipt['c_compile']['v_prod'] = False
        self.receipt_path.write_text(json.dumps(self.receipt))
        with self.assertRaisesRegex(RuntimeError, 'completed Linux build'):
            self.package()
        self.assertFalse(self.output.exists())

    def test_wrong_package_identity_or_changed_payload_is_never_published(self):
        self.package_identity = 'vox 0.1-1'
        with self.assertRaisesRegex(RuntimeError, 'wrong name or version'):
            self.package()
        self.package_identity = 'vox 0.1.4-1'
        self.corrupt_payload = True
        with self.assertRaisesRegex(RuntimeError, 'payload does not match'):
            self.package()
        self.assertFalse(self.output.exists())
        self.assertFalse(any('--headless-smoke' in command for command in self.commands))

    def test_optional_avif_helper_is_packaged_and_checked(self):
        helper = self.source.with_name('libVoxAVIF.so')
        helper.write_bytes(b'AVIF fixture with symbols')
        before = deploy.sha256(helper)
        self.package()
        manifest = json.loads(self.output.with_name(self.output.name + '.json').read_text())
        self.assertEqual(manifest['source_binaries_sha256']['libVoxAVIF.so'], before)
        self.assertIn('libVoxAVIF.so', manifest['sizes'])
        self.assertEqual(deploy.sha256(helper), before)

    def test_output_cannot_overwrite_linux_inputs(self):
        self.output = self.source.parent / 'vox.pkg.tar.zst'
        with self.assertRaisesRegex(RuntimeError, 'outside the canonical'):
            self.package()

    def test_root_and_unsupported_architecture_fail_before_building(self):
        with patch.object(deploy.os, 'geteuid', return_value=0):
            with self.assertRaisesRegex(RuntimeError, 'regular user'):
                deploy.deploy(self.root)
        with patch.object(deploy.os, 'geteuid', return_value=1000), \
                patch.object(deploy.shutil, 'which', return_value='/usr/bin/tool'), \
                patch.object(deploy.platform, 'machine', return_value='aarch64'):
            with self.assertRaisesRegex(RuntimeError, 'x86_64 build host'):
                deploy.deploy(self.root)
        self.assertEqual(self.commands, [])

    @unittest.skipUnless(sys.platform == 'linux' and shutil.which('makepkg'), 'requires native Arch tools')
    def test_real_arch_tools_strip_package_extract_and_run_an_elf_fixture(self):
        # This is package-format/install-layout coverage, not browser acceptance.
        shutil.copyfile('/usr/bin/true', self.source)
        self.source.chmod(0o755)
        self.receipt['executable_sha256'] = deploy.sha256(self.source)
        self.receipt_path.write_text(json.dumps(self.receipt))

        def guarded(command, root, work, name, limit_gib=12, **kwargs):
            subprocess.run([sys.executable, str(deploy.ROOT / 'tools/run_memory_bounded.py'),
                            '--lock', str(work / (name + '.lock')),
                            '--report', str(work / (name + '.json')), '--limit-gib', str(limit_gib),
                            '--', *map(str, command)], cwd=root, check=True, **kwargs)
            return json.loads((work / (name + '.json')).read_text())

        with patch.object(deploy, 'guarded', side_effect=guarded), redirect_stdout(io.StringIO()):
            deploy.deploy(self.root, self.output, package_only=True)
        metadata = subprocess.check_output(['bsdtar', '-xOf', self.output, '.PKGINFO'], text=True)
        self.assertIn('pkgname = vox\n', metadata)
        self.assertIn('pkgver = 0.1.4-1\n', metadata)
        self.assertIn('depend = glibc\n', metadata)
        self.assertIn('arch = x86_64\n', metadata)
        manifest = json.loads(self.output.with_name(self.output.name + '.json').read_text())
        for report in manifest['memory_reports'].values():
            self.assertEqual(report['child_exit_code'], 0)
        # Opt in only in a disposable Arch VM/container, never on a developer's
        # ordinary machine. The fixture proves pacman installation, not Vox UI.
        if os.getenv('VOX_ARCH_TEST_INSTALL') == '1':
            existing = subprocess.run(['pacman', '-Q', 'vox'], capture_output=True)
            self.assertNotEqual(existing.returncode, 0, 'The test requires a VM without Vox installed')
            subprocess.run(['sudo', '-n', 'pacman', '-U', '--noconfirm', str(self.output)], check=True)
            try:
                subprocess.run(['pacman', '-Qkk', 'vox'], check=True)
                self.assertEqual(deploy.sha256(Path('/usr/bin/vox').resolve()),
                                 manifest['packaged_executable_sha256'])
                with tempfile.TemporaryDirectory(prefix='vox-arch-installed-') as directory:
                    guarded(['/usr/bin/vox', '--headless-smoke'], self.root, Path(directory), 'installed', 3)
            finally:
                subprocess.run(['sudo', '-n', 'pacman', '-R', '--noconfirm', 'vox'], check=True)


if __name__ == '__main__':
    unittest.main()
