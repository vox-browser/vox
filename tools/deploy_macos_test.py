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

import deploy_macos as deploy


class MacOSDeployTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='vox-release-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        patcher = patch.object(deploy, 'minimum_macos', return_value=(14, 0))
        patcher.start()
        self.addCleanup(patcher.stop)
        self.app = self.root / 'Build/v/Vox.app'
        binaries = self.app / 'Contents/MacOS'
        binaries.mkdir(parents=True)
        for name in ('Vox', 'VoxAdblockWorker'):
            (binaries / name).write_bytes(b'synthetic Mach-O fixture with symbols')
            (binaries / name).chmod(0o755)
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(
            dict(CFBundleShortVersionString='0.1', LSMinimumSystemVersion='15.0')))
        (self.app / 'Contents/link').symlink_to('MacOS/Vox')
        packaging = self.root / 'packaging'
        packaging.mkdir()
        for name in (deploy.README, 'Vox.entitlements.plist'):
            (packaging / name).write_bytes((deploy.ROOT / 'packaging' / name).read_bytes())
        self.receipt_path = self.root / 'Build/production-build/latest.json'
        self.receipt_path.parent.mkdir(parents=True)
        self.receipt = dict(exit=0, c_compile=dict(mode='single', requested='single', v_prod=True),
                            executable_sha256=deploy.sha256(binaries / 'Vox'))
        self.receipt_path.write_text(json.dumps(self.receipt))
        self.output = self.root / 'release with spaces/Vox.dmg'
        self.commands = []
        self.environments = []
        self.fail = None

    def fake_run(self, command, root, **kwargs):
        command = [str(part) for part in command]
        self.commands.append(command)
        self.environments.append(kwargs.get('env', {}))
        effective = command[command.index('--') + 1:] if '--' in command else command
        if self.fail and self.fail in effective:
            raise subprocess.CalledProcessError(1, command)
        if effective[0] == '/usr/bin/ditto':
            shutil.copytree(effective[1], effective[2], symlinks=True)
        elif effective[0] == '/usr/bin/strip':
            Path(effective[-1]).write_bytes(b'stripped fixture')
        elif effective[:2] == ['/usr/bin/hdiutil', 'create']:
            payload = Path(effective[effective.index('-srcfolder') + 1])
            self.assertEqual(sorted(p.name for p in payload.iterdir()),
                             sorted(['Vox.app', 'Applications', deploy.README]))
            self.assertEqual((payload / 'Applications').readlink(), Path('/Applications'))
            self.assertEqual((payload / deploy.README).read_bytes(),
                             (self.root / 'packaging' / deploy.README).read_bytes())
            Path(effective[-1]).write_bytes(b'synthetic compressed DMG')

    def package(self, package_only=True):
        with patch.object(deploy, 'run', side_effect=self.fake_run), redirect_stdout(io.StringIO()):
            return deploy.deploy(self.root, self.output, package_only=package_only)

    def test_release_stages_strips_resigns_and_smokes_without_altering_the_shared_app(self):
        before = deploy.bundle_identity(self.app)
        self.assertEqual(self.package(), self.output.resolve())
        self.assertEqual(deploy.bundle_identity(self.app), before)
        self.assertTrue(self.output.is_file())
        manifest = json.loads(self.output.with_suffix('.dmg.json').read_text())
        self.assertEqual(manifest['source_bundle_sha256'], before)
        self.assertNotEqual(manifest['packaged_bundle_sha256'], before)
        self.assertEqual(manifest['dmg_sha256'], deploy.sha256(self.output))
        self.assertLess(manifest['sizes']['Vox']['stripped'], manifest['sizes']['Vox']['before'])
        operations = [c[c.index('--') + 1:] if '--' in c else c for c in self.commands]
        self.assertEqual([c[0] for c in operations[:6]], ['/usr/bin/ditto', '/usr/bin/strip',
                         '/usr/bin/strip', '/usr/bin/codesign', '/usr/bin/codesign', '/usr/bin/codesign'])
        for command in operations[3:5]:
            self.assertIn('--entitlements', command)
        self.assertEqual(operations[6][-1], '--headless-smoke')
        self.assertEqual(operations[-1][:2], ['/usr/bin/hdiutil', 'verify'])
        self.assertFalse(any('rebuild_browser.py' in part for c in operations for part in c))

    def test_default_build_requests_c_backend_literal_prod_and_single_unit_without_overrides(self):
        with patch.dict(os.environ, VOX_BUILD_SUPERVISED='1', VOX_BUILD_BACKEND='fastc',
                        LADYBIRD_V_PROFILE='profile'):
            self.package(package_only=False)
        self.assertEqual(self.commands[0], [sys.executable, str(self.root / 'tools/rebuild_browser.py'),
                                           '--build', '--backend', 'c',
                                           '--prod', '--no-parallel-cc'])
        self.assertNotIn('VOX_BUILD_SUPERVISED', self.environments[0])
        self.assertNotIn('VOX_BUILD_BACKEND', self.environments[0])
        self.assertNotIn('LADYBIRD_V_PROFILE', self.environments[0])

    def test_failed_release_build_stops_before_staging_or_using_an_older_bundle(self):
        before = deploy.bundle_identity(self.app)
        self.fail = str(self.root / 'tools/rebuild_browser.py')
        with self.assertRaises(subprocess.CalledProcessError):
            self.package(package_only=False)
        self.assertEqual(len(self.commands), 1)
        self.assertEqual(deploy.bundle_identity(self.app), before)
        self.assertFalse(self.output.exists())

    def test_wrong_build_mode_or_changed_executable_never_produces_a_release(self):
        for mode in [dict(backend='fastc', mode='fastc', requested='single', v_prod=True),
                     dict(mode='parallel', requested='parallel', v_prod=True),
                     dict(mode='single', requested='parallel', v_prod=True),
                     dict(mode='single', requested='single', v_prod=False)]:
            self.receipt_path.write_text(json.dumps(dict(self.receipt, c_compile=mode)))
            with self.assertRaisesRegex(RuntimeError, '--prod --no-parallel-cc'):
                self.package()
        self.receipt_path.write_text(json.dumps(self.receipt))
        (self.app / 'Contents/MacOS/Vox').write_bytes(b'changed executable')
        with self.assertRaisesRegex(RuntimeError, 'does not match'):
            self.package()
        self.assertFalse(self.output.exists())
        self.assertEqual(self.commands, [])

    def test_failed_strip_signing_smoke_or_image_verification_preserves_existing_release(self):
        before = deploy.bundle_identity(self.app)
        self.output.parent.mkdir()
        self.output.write_bytes(b'previous release')
        for failure in ['/usr/bin/strip', '/usr/bin/codesign', '--headless-smoke', 'verify']:
            self.fail = failure
            with self.assertRaises(subprocess.CalledProcessError):
                self.package()
            self.assertEqual(self.output.read_bytes(), b'previous release')
            self.assertEqual(deploy.bundle_identity(self.app), before)
            self.assertFalse(self.output.with_suffix('.dmg.json').exists())

    def test_release_loading_libraries_from_outside_the_app_is_rejected(self):
        staged = []
        with patch.object(deploy, 'bundle_libraries', side_effect=staged.append), \
                patch.object(deploy, 'verify_self_contained', side_effect=RuntimeError('not self-contained')):
            with self.assertRaisesRegex(RuntimeError, 'not self-contained'):
                self.package()
        # Libraries are copied into the staged release, never the shared app.
        self.assertEqual(len(staged), 1)
        self.assertEqual(staged[0].name, 'Vox.app')
        self.assertFalse(staged[0].is_relative_to(self.root))
        self.assertFalse(any('hdiutil' in part for command in self.commands for part in command))
        self.assertFalse(self.output.exists())

    def test_bundle_requiring_newer_than_its_declared_macos_is_rejected(self):
        with patch.object(deploy, 'minimum_macos', return_value=(15, 0)):
            self.package()
        self.output.unlink()
        with patch.object(deploy, 'minimum_macos', return_value=(15, 1)):
            with self.assertRaisesRegex(RuntimeError, 'requires macOS 15.1; the release declares macOS 15.0'):
                self.package()
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
