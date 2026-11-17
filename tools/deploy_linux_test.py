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

import deploy_linux as deploy


class LinuxDeployTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-linux-deploy-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / 'Build/linux/vox'
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(b'ELF fixture with debug symbols')
        self.source.chmod(0o755)
        self.helper = self.source.with_name('libVoxAVIF.so')
        self.helper.write_bytes(b'AVIF library with symbols')
        self.receipt_path = self.root / 'Build/linux/production-build/latest.json'
        self.receipt_path.parent.mkdir()
        self.receipt = dict(exit=0, executable_sha256=deploy.sha256(self.source),
                            c_compile=dict(backend='c', mode='single', requested='single', v_prod=True))
        self.receipt_path.write_text(json.dumps(self.receipt))
        packaging = self.root / 'packaging'
        packaging.mkdir()
        (packaging / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleShortVersionString='0.1.2')))
        (packaging / 'version.txt').write_text('0.1.2\n')
        for name in ('Vox.png', 'vox.desktop'):
            shutil.copyfile(deploy.ROOT / 'packaging' / name, packaging / name)
        for name in ('LICENSE', 'THIRD_PARTY_NOTICES.md'):
            shutil.copyfile(deploy.ROOT / name, self.root / name)
        self.output = self.root / 'release with spaces/Vox.deb'
        self.commands = []
        self.environments = []
        self.failure = None
        self.payload = None
        self.dependencies = 'shlibs:Depends=libc6 (>= 2.38), libjavascriptcoregtk-4.1-0 (>= 2.46)\n'

    def fake_run(self, command, root, **kwargs):
        command = [str(part) for part in command]
        self.commands.append(command)
        self.environments.append(kwargs.get('env', {}))
        effective = command[command.index('--') + 1:] if '--' in command else command
        if self.failure and self.failure in effective:
            raise subprocess.CalledProcessError(1, command)
        stdout = ''
        if effective[:2] == ['dpkg', '--print-architecture']:
            stdout = 'arm64\n'
        elif effective[0] == 'dpkg-shlibdeps':
            self.assertEqual(root.name[:9], '.vox-deb-')
            self.assertTrue((root / 'debian/control').is_file())
            self.assertEqual([Path(part[2:]).name for part in effective if part.startswith('-e')],
                             ['vox', 'libVoxAVIF.so'] if self.helper.exists() else ['vox'])
            stdout = self.dependencies
        elif effective[0] == 'strip':
            self.assertEqual(effective[1], '--strip-unneeded')
            Path(effective[-1]).write_bytes(b'stripped ELF')
        elif effective[:3] == ['dpkg-deb', '--root-owner-group', '--build']:
            self.payload = Path(effective[-2])
            self.control = (self.payload / 'DEBIAN/control').read_text()
            self.assertEqual((self.payload / 'usr/bin/vox').readlink(), Path('../lib/vox/vox'))
            self.assertEqual((self.payload / 'usr/share/applications/vox.desktop').read_bytes(),
                             (self.root / 'packaging/vox.desktop').read_bytes())
            Path(effective[-1]).write_bytes(b'Debian archive fixture')
        elif effective[:2] == ['dpkg-deb', '--extract']:
            shutil.copytree(self.payload, effective[-1], symlinks=True)
        elif effective[-1] == '--headless-smoke':
            executable = Path(effective[0])
            self.assertTrue(executable.is_symlink())
            self.assertEqual(executable.read_bytes(), b'stripped ELF')
            self.assertTrue((executable.resolve().parent / 'libVoxAVIF.so').is_file()
                            == self.helper.exists())
            self.assertNotIn('VOX_PROXY', kwargs['env'])
        if '--report' in command:
            Path(command[command.index('--report') + 1]).write_text(json.dumps(dict(exit=0)))
        return subprocess.CompletedProcess(command, 0, stdout=stdout)

    def package(self, package_only=True):
        with patch.object(deploy, 'run', side_effect=self.fake_run), \
                patch.object(deploy.shutil, 'which', return_value='/usr/bin/tool'), \
                redirect_stdout(io.StringIO()):
            return deploy.deploy(self.root, self.output, package_only)

    def test_deb_contains_stripped_binaries_desktop_icon_dependencies_and_smoked_install_layout(self):
        before = {path.name: deploy.sha256(path) for path in (self.source, self.helper)}
        with patch.dict(os.environ, VOX_PROXY='http://invalid.example'):
            self.assertEqual(self.package(), self.output.resolve())
        self.assertEqual(before, {path.name: deploy.sha256(path) for path in (self.source, self.helper)})
        self.assertIn('Version: 0.1.2\nArchitecture: arm64\n', self.control)
        self.assertIn('Depends: libc6 (>= 2.38), libjavascriptcoregtk-4.1-0 (>= 2.46), '
                      'ca-certificates, fonts-dejavu-core\n', self.control)
        manifest = json.loads(self.output.with_suffix('.deb.json').read_text())
        self.assertEqual(manifest['source_binaries_sha256'], before)
        self.assertEqual(manifest['source_build'], self.receipt)
        self.assertEqual(manifest['deb_sha256'], deploy.sha256(self.output))
        self.assertLess(manifest['sizes']['vox']['stripped'], manifest['sizes']['vox']['before'])
        self.assertEqual(set(manifest['memory_reports']), {'create', 'extract', 'smoke'})
        self.assertFalse(any('rebuild_browser' in command for command in self.commands))
        self.assertEqual(set(self.output.parent.iterdir()), {self.output, self.output.with_suffix('.deb.json')})

    def test_default_build_requests_managed_c_backend_literal_prod_and_single_unit(self):
        with patch.dict(os.environ, VOX_BUILD_SUPERVISED='1', VOX_BUILD_BACKEND='fastc',
                        VOX_LINUX_CFLAGS='-O0', LADYBIRD_V_PROFILE='profile'):
            self.package(package_only=False)
        command = self.commands[1]
        self.assertEqual(command, ['sh', str(self.root / 'tools/run_v_tool.sh'), 'rebuild_browser',
                                   '--build', '--backend', 'c', '--prod', '--no-parallel-cc'])
        for key in ('VOX_BUILD_SUPERVISED', 'VOX_BUILD_BACKEND', 'VOX_LINUX_CFLAGS', 'LADYBIRD_V_PROFILE'):
            self.assertNotIn(key, self.environments[1])

    def test_stale_runtime_version_stops_before_building_or_packaging(self):
        (self.root / 'packaging/version.txt').write_text('0.1\n')
        for package_only in (True, False):
            with self.assertRaisesRegex(RuntimeError, 'wrong installed version'):
                self.package(package_only=package_only)
        self.assertEqual(self.commands, [])
        self.assertFalse(self.output.exists())

    def test_non_prod_fastc_failed_or_mismatched_build_cannot_be_packaged(self):
        for changes in (dict(exit=1), dict(executable_sha256='changed'),
                        dict(c_compile={}), dict(c_compile=dict(self.receipt['c_compile'], backend='fastc')),
                        dict(c_compile=dict(self.receipt['c_compile'], v_prod=False))):
            self.receipt_path.write_text(json.dumps(dict(self.receipt, **changes)))
            with self.subTest(changes=changes), self.assertRaises(RuntimeError):
                self.package()
            self.assertFalse(self.output.exists())
        self.assertFalse(any('strip' in command for command in self.commands))

    def test_failure_preserves_previous_package_and_cleans_staging_and_guard_files(self):
        self.output.parent.mkdir()
        self.output.write_bytes(b'previous release')
        for failure in ('rebuild_browser', 'strip', 'dpkg-shlibdeps', '--build', '--info',
                        '--extract', '--headless-smoke'):
            self.failure = failure
            with self.subTest(failure=failure), self.assertRaises(subprocess.CalledProcessError):
                self.package(package_only=failure != 'rebuild_browser')
            self.assertEqual(self.output.read_bytes(), b'previous release')
            self.assertEqual(list(self.output.parent.iterdir()), [self.output])

    def test_optional_avif_helper_can_be_absent(self):
        self.helper.unlink()
        self.package()
        manifest = json.loads(self.output.with_suffix('.deb.json').read_text())
        self.assertEqual(set(manifest['sizes']), {'vox'})

    def test_missing_dependency_information_is_fatal(self):
        self.dependencies = ''
        with self.assertRaisesRegex(RuntimeError, 'runtime dependencies'):
            self.package()
        self.assertFalse(self.output.exists())

    def test_output_cannot_overwrite_linux_build_inputs(self):
        for output in (self.source, self.source.parent / 'browser.deb'):
            self.output = output
            with self.subTest(output=output), self.assertRaisesRegex(RuntimeError, 'outside the canonical'):
                self.package()
        self.assertEqual(self.source.read_bytes(), b'ELF fixture with debug symbols')

    @unittest.skipUnless(sys.platform == 'linux' and all(shutil.which(tool) for tool in
                         ('dpkg', 'dpkg-deb', 'dpkg-shlibdeps', 'strip')),
                         'requires native Debian packaging tools')
    def test_real_debian_tools_strip_package_extract_and_run_an_elf_fixture(self):
        # A small host ELF exercises real dpkg dependency resolution and archive
        # layout without building the browser. It is not browser smoke evidence.
        shutil.copyfile('/bin/true', self.source)
        self.source.chmod(0o755)
        self.helper.unlink()
        self.receipt['executable_sha256'] = deploy.sha256(self.source)
        self.receipt_path.write_text(json.dumps(self.receipt))

        def guarded(command, root, work, name, limit_gib=12, **kwargs):
            # Use the reference Python guard so packaging regressions also run
            # before V is installed in the Linux CI preflight.
            subprocess.run([sys.executable, str(deploy.ROOT / 'tools/run_memory_bounded.py'),
                            '--lock', str(work / (name + '.lock')),
                            '--report', str(work / (name + '.json')),
                            '--limit-gib', str(limit_gib), '--', *map(str, command)],
                           cwd=root, check=True, **kwargs)
            return json.loads((work / (name + '.json')).read_text())

        with patch.object(deploy, 'guarded', side_effect=guarded), redirect_stdout(io.StringIO()):
            deploy.deploy(self.root, self.output, package_only=True)
        result = subprocess.run(['dpkg-deb', '--field', str(self.output), 'Package', 'Version',
                                 'Architecture', 'Depends'], check=True, capture_output=True, text=True)
        self.assertIn('Package: vox\nVersion: 0.1.2\n', result.stdout)
        self.assertIn('libc6', result.stdout)
        manifest = json.loads(self.output.with_suffix('.deb.json').read_text())
        self.assertEqual(manifest['deb_sha256'], deploy.sha256(self.output))
        for report in manifest['memory_reports'].values():
            self.assertEqual(report['reason'], 'completed')
            self.assertEqual(report['child_exit_code'], 0)


class DeployPlatformTests(unittest.TestCase):
    def main(self, platform, arguments):
        import deploy_macos
        with patch.object(sys, 'platform', platform), \
                patch.object(deploy_macos, 'linux_package_format', return_value='deb'), \
                patch.object(sys, 'argv', ['deploy.vsh', *arguments]):
            return deploy_macos.main()

    def test_linux_no_publish_routes_to_debian_packager(self):
        with patch.object(deploy, 'deploy') as package:
            self.assertEqual(self.main('linux', ['--no-publish', '--package-only',
                                                 '--output', 'Vox.deb']), 0)
        package.assert_called_once_with(output=Path('Vox.deb'), package_only=True)

    def test_linux_publishing_routes_through_committed_release_flow(self):
        import deploy_macos
        with patch.object(deploy, 'deploy') as package, \
                patch.object(deploy_macos.release_macos, 'release') as release:
            self.assertEqual(self.main('linux', ['--version', '0.2.0']), 0)
        release.assert_called_once_with(deploy_macos.ROOT, package, None, False, '0.2.0', target='linux')

    def test_macos_keeps_existing_dmg_packager(self):
        import deploy_macos
        with patch.object(deploy_macos, 'deploy') as package:
            self.assertEqual(self.main('darwin', ['--no-publish']), 0)
        package.assert_called_once_with(output=None, package_only=False)

    def test_arch_format_routes_to_native_arch_packager_and_release_target(self):
        import deploy_arch
        import deploy_macos
        with patch.object(deploy_arch, 'deploy') as package:
            self.assertEqual(self.main('linux', ['--format', 'arch', '--no-publish']), 0)
        package.assert_called_once_with(output=None, package_only=False)
        with patch.object(deploy_arch, 'deploy') as package, \
                patch.object(deploy_macos.release_macos, 'release') as release:
            self.assertEqual(self.main('linux', ['--format', 'arch']), 0)
        release.assert_called_once_with(deploy_macos.ROOT, package, None, False, None, target='linux-arch')

    def test_arch_detection_includes_arch_derivatives(self):
        import deploy_macos
        for release, expected in ((dict(ID='arch'), 'arch'),
                                  (dict(ID='endeavouros', ID_LIKE='arch'), 'arch'),
                                  (dict(ID='debian'), 'deb'), (dict(ID='ubuntu', ID_LIKE='debian'), 'deb')):
            with patch.object(os, 'freedesktop_os_release', return_value=release, create=True):
                self.assertEqual(deploy_macos.linux_package_format(), expected)

    def test_staged_arch_release_builds_clean_sources_without_publishing(self):
        import deploy_arch
        import deploy_macos
        with patch.object(deploy_arch, 'deploy') as package, \
                patch.object(deploy_macos.release_macos, 'release') as release:
            self.assertEqual(self.main('linux', ['--format', 'arch', '--stage-release', '--version', '0.1.5']), 0)
        release.assert_called_once_with(deploy_macos.ROOT, package, None, False, '0.1.5',
                                        target='linux-arch', publish=False)


if __name__ == '__main__':
    unittest.main()
