from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import release_macos as release

ROOT = Path(__file__).resolve().parents[1]


class VersionTests(unittest.TestCase):
    def test_next_release_is_a_patch_bump_unless_info_plist_or_the_caller_chose_one(self):
        self.assertEqual(release.next_version('0.1', '0.1.0'), '0.1.1')
        self.assertEqual(release.next_version('0.1.0', '0.1.9'), '0.1.10')
        # An interrupted release or a manual minor bump keeps its version.
        self.assertEqual(release.next_version('0.1.1', '0.1.0'), '0.1.1')
        self.assertEqual(release.next_version('0.3', '0.2.4'), '0.3.0')
        self.assertEqual(release.next_version('0.1', '0.1.0', '0.2'), '0.2.0')
        for current, released, requested in [('0.1', '0.1.0', '0.1.0'), ('0.1', '0.2.0', '0.1.5'),
                                              ('0.1', '0.1.0', 'v0.2'), ('0.1', 'latest', None)]:
            with self.assertRaises(ValueError):
                release.next_version(current, released, requested)

    def test_info_plist_update_keeps_formatting_and_advances_the_build_once(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'Info.plist'
            original = (ROOT / release.INFO_PLIST).read_text()
            path.write_text(original)
            before = plistlib.loads(original.encode())
            self.assertTrue(release.set_bundle_version(path, '0.1.1'))
            updated = path.read_text()
            info = plistlib.loads(updated.encode())
            self.assertEqual(info['CFBundleShortVersionString'], '0.1.1')
            self.assertEqual(info['CFBundleVersion'], str(int(before['CFBundleVersion']) + 1))
            self.assertEqual({k: v for k, v in info.items() if not k.startswith('CFBundle') or 'Version' not in k},
                             {k: v for k, v in before.items() if not k.startswith('CFBundle') or 'Version' not in k})
            self.assertEqual(len(updated.splitlines()), len(original.splitlines()))
            # browserupdate embeds the raw plist and reads the string after the key.
            self.assertEqual(updated.split('<key>CFBundleShortVersionString</key>')[1]
                             .split('<string>')[1].split('</string>')[0], '0.1.1')
            self.assertFalse(release.set_bundle_version(path, '0.1.1'))
            self.assertEqual(path.read_text(), updated)


class ReleaseFlowTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-release-flow-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'packaging').mkdir()
        (self.root / release.INFO_PLIST).write_text((ROOT / release.INFO_PLIST).read_text())
        self.calls = []
        self.fail = None
        for name in ('check_unreleased', 'check_website', 'publish_release',
                     'commit_version', 'publish_website_version'):
            patcher = patch.object(release, name, side_effect=self.recorder(name))
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = patch.object(release, 'released_version', return_value='0.1.0')
        patcher.start()
        self.addCleanup(patcher.stop)

    def recorder(self, name):
        def record(*arguments):
            self.calls.append((name, arguments))
            if self.fail == name:
                raise RuntimeError(name + ' failed')
        return record

    def deploy(self, root, output, package_only):
        self.calls.append(('deploy', (release.bundle_version(root / release.INFO_PLIST), package_only)))
        if self.fail == 'deploy':
            raise subprocess.CalledProcessError(1, ['build'])
        dmg = self.root / 'Build/deploy/Vox-0.1.1-arm64.dmg'
        dmg.parent.mkdir(parents=True, exist_ok=True)
        dmg.write_bytes(b'dmg')
        dmg.with_suffix('.dmg.json').write_text(json.dumps(dict(
            version=release.bundle_version(root / release.INFO_PLIST))))
        return dmg

    def release(self, **kwargs):
        with redirect_stdout(io.StringIO()):
            return release.release(self.root, self.deploy, **kwargs)

    def test_release_checks_before_building_and_publishes_github_before_the_website(self):
        dmg = self.release()
        self.assertEqual([name for name, _ in self.calls],
                         ['check_unreleased', 'check_website', 'deploy', 'publish_release',
                          'commit_version', 'publish_website_version'])
        self.assertEqual(self.calls[0][1], (release.REPOSITORY, '0.1.1'))
        # The version is bumped before the build embeds Info.plist.
        self.assertEqual(self.calls[2][1], ('0.1.1', False))
        self.assertEqual(self.calls[3][1], (release.REPOSITORY, '0.1.1', dmg, '26.0'))
        self.assertEqual(self.calls[5][1], ('0.1.1', release.WEBSITE_HOST))

    def test_failed_build_or_upload_publishes_nothing_further_and_a_rerun_keeps_the_version(self):
        for failure, published in [('deploy', []), ('publish_release', ['publish_release'])]:
            self.calls.clear()
            self.fail = failure
            with self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
                self.release()
            names = [name for name, _ in self.calls]
            self.assertEqual([n for n in names if n.startswith(('publish', 'commit'))], published)
            self.assertEqual(release.bundle_version(self.root / release.INFO_PLIST), '0.1.1')
        self.fail = None
        self.calls.clear()
        self.release()
        self.assertEqual(self.calls[0][1], (release.REPOSITORY, '0.1.1'))

    def test_unavailable_tag_or_server_stops_before_the_build(self):
        for failure in ('check_unreleased', 'check_website'):
            self.calls.clear()
            self.fail = failure
            with self.assertRaisesRegex(RuntimeError, failure):
                self.release()
            self.assertNotIn('deploy', [name for name, _ in self.calls])
        self.assertEqual(release.bundle_version(self.root / release.INFO_PLIST), '0.1')

    def test_package_only_requires_a_build_of_the_release_version(self):
        built = self.root / 'Build/v/Vox.app/Contents/Info.plist'
        built.parent.mkdir(parents=True)
        built.write_text((ROOT / release.INFO_PLIST).read_text())
        with self.assertRaisesRegex(RuntimeError, 'version 0.1; run deploy.vsh without --package-only'):
            self.release(package_only=True)
        self.assertNotIn('deploy', [name for name, _ in self.calls])
        release.set_bundle_version(self.root / release.INFO_PLIST, '0.1.1')
        release.set_bundle_version(built, '0.1.1')
        self.calls.clear()
        self.release(package_only=True)
        self.assertEqual(self.calls[2], ('deploy', ('0.1.1', True)))


class PublishingTests(unittest.TestCase):
    def completed(self, code=0, stdout='', stderr=''):
        return subprocess.CompletedProcess([], code, stdout, stderr)

    def test_existing_release_or_tag_is_refused_and_other_github_errors_surface(self):
        missing = self.completed(1, stderr='release not found')
        with patch.object(release.subprocess, 'run', side_effect=[missing, self.completed(1, stderr='HTTP 404')]):
            release.check_unreleased('owner/repo', '0.1.1')
        with patch.object(release.subprocess, 'run', return_value=self.completed()):
            with self.assertRaisesRegex(RuntimeError, 'already has a release 0.1.1'):
                release.check_unreleased('owner/repo', '0.1.1')
        with patch.object(release.subprocess, 'run', side_effect=[missing, self.completed()]):
            with self.assertRaisesRegex(RuntimeError, 'already has a tag 0.1.1'):
                release.check_unreleased('owner/repo', '0.1.1')
        with patch.object(release.subprocess, 'run', return_value=self.completed(1, stderr='authentication required')):
            with self.assertRaisesRegex(RuntimeError, 'authentication required'):
                release.check_unreleased('owner/repo', '0.1.1')

    def test_uploaded_dmg_must_match_the_local_checksum(self):
        with tempfile.TemporaryDirectory() as temporary:
            dmg = Path(temporary) / 'Vox-0.1.1-arm64.dmg'
            dmg.write_bytes(b'dmg')
            commands = []

            def run(arguments, **kwargs):
                commands.append(arguments)
                digest = 'sha256:' + release.sha256(dmg) if len(commands) == 2 else 'sha256:0'
                return self.completed(stdout=json.dumps(dict(assets=[dict(name=dmg.name, digest=digest)])))

            with patch.object(release.subprocess, 'run', side_effect=run), redirect_stdout(io.StringIO()):
                release.publish_release('owner/repo', '0.1.1', dmg, '26.0')
                self.assertEqual(commands[0][:6], ['gh', 'release', 'create', '0.1.1', str(dmg), '-R'])
                self.assertIn('macOS 26.0 or later', commands[0][commands[0].index('--notes') + 1])
                with self.assertRaisesRegex(RuntimeError, 'does not carry'):
                    release.publish_release('owner/repo', '0.1.1', dmg, '26.0')

    def test_website_version_is_replaced_atomically_and_checked_live(self):
        with patch.object(release.subprocess, 'run', return_value=self.completed()) as run, \
                patch.object(release, 'live_version', return_value='0.1.1'), redirect_stdout(io.StringIO()):
            release.publish_website_version('0.1.1', 'host')
        arguments, options = run.call_args
        self.assertEqual(arguments[0][:-1], ['ssh', *release.SSH_OPTIONS, 'host'])
        self.assertIn('mv -f "$temporary" /var/www/vox-browser.org/version', arguments[0][-1])
        self.assertEqual(options['input'], '0.1.1\n')
        with patch.object(release.subprocess, 'run', return_value=self.completed()), \
                patch.object(release, 'live_version', return_value='0.1.0'), redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "serves '0.1.0'.*--website-only"):
                release.publish_website_version('0.1.1', 'host')


if __name__ == '__main__':
    unittest.main()
