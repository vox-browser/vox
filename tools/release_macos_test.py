from contextlib import redirect_stdout
import io
import json
import re
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import release_macos as release

ROOT = Path(__file__).resolve().parents[1]


def info_plist(version='0.1', build='1'):
    """The real Info.plist at a fixed version, independent of the next release."""
    text = (ROOT / release.INFO_PLIST).read_text()
    for key, value in (('CFBundleShortVersionString', version), ('CFBundleVersion', build)):
        text = re.sub(r'(<key>%s</key>\s*<string>)[^<]*' % key, lambda m: m.group(1) + value, text)
    return text


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
            original = info_plist()
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


def git(root, *arguments):
    return subprocess.run(['git', '-C', str(root), '-c', 'user.name=Vox', '-c',
                           'user.email=vox@example.com', *arguments],
                          check=True, capture_output=True, text=True).stdout.strip()


def repository(root, files):
    for name, content in files.items():
        (root / name).parent.mkdir(parents=True, exist_ok=True)
        (root / name).write_text(content)
    git(root, 'init', '-q', '-b', 'master')
    git(root, 'config', 'user.name', 'Vox')
    git(root, 'config', 'user.email', 'vox@example.com')
    git(root, 'add', '.')
    git(root, 'commit', '-q', '-m', 'fixture')
    return git(root, 'rev-parse', 'HEAD')


class ReleaseFlowTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-release-flow-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name) / 'vox2'
        self.checkout = Path(temporary.name) / 'vox2-release'
        (self.root / 'packaging').mkdir(parents=True)
        (self.root / release.INFO_PLIST).write_text(info_plist())
        self.calls = []
        self.failing = None
        self.commit = 'c0ffee'
        self.compiled = dict(head='c0ffee', build_inputs_sha256='committed tree')
        for name in ('check_unreleased', 'check_website', 'publish_release', 'publish_website_version',
                     'check_download'):
            patcher = patch.object(release, name, side_effect=self.recorder(name))
            patcher.start()
            self.addCleanup(patcher.stop)
        for name, value in [('released_version', '0.1.0'),
                            ('repository_state', dict(build_inputs_sha256='committed tree'))]:
            patcher = patch.object(release, name, return_value=value)
            patcher.start()
            self.addCleanup(patcher.stop)
        for name in ('commit_version', 'prepare_checkout'):
            patcher = patch.object(release, name, side_effect=getattr(self, name))
            patcher.start()
            self.addCleanup(patcher.stop)

    def recorder(self, name):
        def record(*arguments):
            self.calls.append((name, arguments))
            if self.failing == name:
                raise RuntimeError(name + ' failed')
        return record

    def commit_version(self, root, version):
        self.recorder('commit_version')(root, version)
        release.set_bundle_version(root / release.INFO_PLIST, version)
        return self.commit

    def prepare_checkout(self, root, checkout, commit):
        self.recorder('prepare_checkout')(root, checkout, commit)
        (checkout / 'packaging').mkdir(parents=True, exist_ok=True)
        (checkout / release.INFO_PLIST).write_text((root / release.INFO_PLIST).read_text())

    def deploy(self, root, output, package_only):
        self.calls.append(('deploy', (root, release.bundle_version(root / release.INFO_PLIST),
                                      output, package_only)))
        if self.failing == 'deploy':
            raise subprocess.CalledProcessError(1, ['build'])
        dmg = Path(output)
        dmg.parent.mkdir(parents=True, exist_ok=True)
        dmg.write_bytes(b'dmg')
        dmg.with_suffix('.dmg.json').write_text(json.dumps(dict(
            version=release.bundle_version(root / release.INFO_PLIST),
            source_build=dict(verified_inputs=self.compiled))))
        return dmg

    def release(self, **kwargs):
        with redirect_stdout(io.StringIO()):
            return release.release(self.root, self.deploy, checkout=self.checkout, **kwargs)

    def names(self):
        return [name for name, _ in self.calls]

    def test_release_commits_the_bump_builds_that_commit_elsewhere_then_publishes(self):
        dmg = self.release()
        self.assertEqual(self.names(), ['check_unreleased', 'check_website', 'commit_version',
                                        'prepare_checkout', 'deploy', 'publish_release',
                                        'publish_website_version', 'check_download'])
        self.assertEqual(self.calls[0][1], (release.REPOSITORY, '0.1.1'))
        self.assertEqual(self.calls[3][1], (self.root, self.checkout, 'c0ffee'))
        # The release checkout builds the committed bump; the DMG lands in the canonical Build/.
        self.assertEqual(self.calls[4][1], (self.checkout, '0.1.1', dmg, False))
        self.assertEqual(dmg, self.root / 'Build/deploy' / ('Vox-0.1.1-%s.dmg' % release.platform.machine()))
        self.assertEqual(self.calls[5][1], (release.REPOSITORY, '0.1.1', dmg, '15.0'))
        self.assertEqual(self.calls[6][1], ('0.1.1', release.WEBSITE_HOST))
        self.assertEqual(self.calls[7][1], (release.REPOSITORY, '0.1.1', dmg.name))

    def test_failed_build_or_upload_publishes_nothing_further_and_a_rerun_keeps_the_version(self):
        for failure, published in [('deploy', []), ('publish_release', ['publish_release'])]:
            self.calls.clear()
            self.failing = failure
            with self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
                self.release()
            self.assertEqual([n for n in self.names() if n.startswith('publish')], published)
        self.failing = None
        self.calls.clear()
        self.release()
        self.assertEqual(self.calls[0][1], (release.REPOSITORY, '0.1.1'))

    def test_build_of_another_commit_or_other_inputs_is_not_published(self):
        for compiled in [dict(self.compiled, head='0ther'),
                         dict(self.compiled, build_inputs_sha256='uncommitted edits'), {}]:
            self.calls.clear()
            self.compiled = compiled
            with self.assertRaisesRegex(RuntimeError, 'did not compile the release commit c0ffee'):
                self.release()
            self.assertEqual(self.names()[-1], 'deploy')

    def test_unavailable_tag_or_server_stops_before_committing(self):
        for failure in ('check_unreleased', 'check_website'):
            self.calls.clear()
            self.failing = failure
            with self.assertRaisesRegex(RuntimeError, failure):
                self.release()
            self.assertNotIn('commit_version', self.names())
            self.assertNotIn('deploy', self.names())
        self.assertEqual(release.bundle_version(self.root / release.INFO_PLIST), '0.1')

    def test_package_only_repackages_the_release_checkout_commit(self):
        with self.assertRaisesRegex(RuntimeError, 'no build of 0.1.1; run deploy.vsh without'):
            self.release(package_only=True)
        self.checkout.mkdir()
        self.compiled['head'] = repository(self.checkout, {release.INFO_PLIST: info_plist('0.1.1', '2')})
        release.set_bundle_version(self.root / release.INFO_PLIST, '0.1.1')
        self.calls.clear()
        self.release(package_only=True)
        self.assertNotIn('commit_version', self.names())
        self.assertNotIn('prepare_checkout', self.names())
        self.assertEqual(self.calls[2][1][::3], (self.checkout, True))

    def test_concurrent_release_is_refused(self):
        with release.release_lock(self.root):
            with self.assertRaisesRegex(RuntimeError, 'Another release is running'):
                self.release()
        self.assertEqual(self.calls, [])


class ReleaseInputTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-release-inputs-')
        self.addCleanup(temporary.cleanup)
        self.checkout = Path(temporary.name)
        self.proof = self.checkout / 'sealed.c'
        self.proof.write_text('consumed compiler input')
        self.inputs = dict(head='release-commit', build_inputs_sha256='repository bytes', dirty=False)
        self.compiled = dict(head='release-commit', build_inputs_sha256='parsed manifest', dirty=True,
                             source_kind='verified parsed buffers and sealed native inputs')
        self.frozen = dict(protocol=release.FROZEN_COMPILE_PROTOCOL, complete=True, compiler_exit=0,
                           sealed_inputs={str(self.proof): release.sha256(self.proof)},
                           source_inputs=self.inputs, source_inputs_at_sealing=self.compiled)
        self.receipt = self.checkout / 'frozen-compile.json'
        self.receipt.write_text(json.dumps(self.frozen))
        self.build = dict(inputs=self.inputs, verified_inputs=self.compiled,
                          frozen_compilation=str(self.receipt))

    def verify(self):
        release.verify_release_inputs(self.checkout, self.build, 'release-commit', 'repository bytes')

    def test_parsed_buffer_hash_is_bound_to_the_clean_checkout_by_its_frozen_proof(self):
        with patch.object(release, 'matches_compiled_checkout', return_value=True) as matches, \
                patch.object(release, 'repository_state', return_value=self.inputs):
            self.verify()
        matches.assert_called_once_with(self.checkout, self.frozen)

    def test_changed_checkout_or_consumed_files_are_never_released(self):
        for current, matching in [(dict(self.inputs, head='another-commit'), True),
                                  (dict(self.inputs, build_inputs_sha256='changed bytes'), True),
                                  (dict(self.inputs, dirty=True), True),
                                  (self.inputs, False)]:
            with self.subTest(current=current, matching=matching), \
                    patch.object(release, 'matches_compiled_checkout', return_value=matching), \
                    patch.object(release, 'repository_state', return_value=current):
                with self.assertRaisesRegex(RuntimeError, 'did not compile the release commit'):
                    self.verify()

    def test_unvalidated_or_mismatched_frozen_receipts_are_never_released(self):
        self.proof.write_text('changed sealed input')
        with self.assertRaisesRegex(RuntimeError, 'Frozen build input changed'):
            self.verify()
        self.proof.write_text('consumed compiler input')
        for frozen in [dict(self.frozen, complete=False), dict(self.frozen, compiler_exit=1),
                       dict(self.frozen, protocol='unknown'), dict(self.frozen, sealed_inputs={}),
                       dict(self.frozen, source_inputs=dict(self.inputs, head='other')),
                       dict(self.frozen, source_inputs_at_sealing=dict(self.compiled, build_inputs_sha256='other'))]:
            self.receipt.write_text(json.dumps(frozen))
            with self.subTest(frozen=frozen), \
                    patch.object(release, 'matches_compiled_checkout', return_value=True), \
                    patch.object(release, 'repository_state', return_value=self.inputs):
                with self.assertRaisesRegex(RuntimeError, 'did not compile the release commit'):
                    self.verify()


class GitTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-release-git-')
        self.addCleanup(temporary.cleanup)
        upstream = Path(temporary.name) / 'upstream'
        upstream.mkdir()
        repository(upstream, {'.gitignore': '/Build/\n', 'main.v': 'older\n',
                              'staged.v': 'committed\n', release.INFO_PLIST: info_plist()})
        (upstream / 'main.v').write_text('committed\n')
        git(upstream, 'commit', '-q', '-am', 'second')
        # Like the canonical checkout, the fixture is a shallow clone.
        self.root = Path(temporary.name) / 'vox2'
        subprocess.run(['git', 'clone', '-q', '--depth', '1', 'file://' + str(upstream), str(self.root)],
                       check=True, capture_output=True)
        git(self.root, 'config', 'user.name', 'Vox')
        git(self.root, 'config', 'user.email', 'vox@example.com')
        self.assertTrue((self.root / '.git/shallow').is_file())
        self.first = git(self.root, 'rev-parse', 'HEAD')

    def test_version_bump_is_committed_alone_while_other_work_stays_uncommitted(self):
        (self.root / 'main.v').write_text('work in progress\n')
        (self.root / 'staged.v').write_text('staged work\n')
        git(self.root, 'add', 'staged.v')
        (self.root / 'new.v').write_text('untracked work\n')
        commit = release.commit_version(self.root, '0.1.1')
        self.assertEqual(commit, git(self.root, 'rev-parse', 'HEAD'))
        self.assertEqual(git(self.root, 'log', '-1', '--format=%s'), 'Release Vox 0.1.1')
        self.assertEqual(git(self.root, 'show', '--format=', '--name-only', 'HEAD'), release.INFO_PLIST)
        self.assertEqual(git(self.root, 'diff', '--cached', '--name-only'), 'staged.v')
        self.assertEqual((self.root / 'main.v').read_text(), 'work in progress\n')
        info = plistlib.loads(git(self.root, 'show', 'HEAD:' + release.INFO_PLIST).encode())
        self.assertEqual((info['CFBundleShortVersionString'], info['CFBundleVersion']), ('0.1.1', '2'))
        # A rerun releases the existing commit.
        self.assertEqual(release.commit_version(self.root, '0.1.1'), commit)
        # An interrupted attempt's uncommitted bump is reused; other plist edits are not committed.
        (self.root / release.INFO_PLIST).write_text(info_plist('0.1.2', '7'))
        self.assertNotEqual(release.commit_version(self.root, '0.1.2'), commit)
        edited = info_plist('0.1.2', '3').replace('<string>15.0</string>', '<string>27.0</string>')
        (self.root / release.INFO_PLIST).write_text(edited)
        head = git(self.root, 'rev-parse', 'HEAD')
        with self.assertRaisesRegex(RuntimeError, 'uncommitted changes besides the version'):
            release.commit_version(self.root, '0.1.3')
        self.assertEqual(git(self.root, 'rev-parse', 'HEAD'), head)

    def test_release_checkout_holds_only_committed_sources_and_keeps_its_build_caches(self):
        (self.root / 'main.v').write_text('work in progress\n')
        (self.root / 'new.v').write_text('untracked work\n')
        checkout = release.release_checkout(self.root)
        self.assertEqual(checkout, self.root.parent / 'vox2-release')
        with redirect_stdout(io.StringIO()):
            release.prepare_checkout(self.root, checkout, self.first)
        self.assertEqual((checkout / 'main.v').read_text(), 'committed\n')
        self.assertFalse((checkout / 'new.v').exists())
        (checkout / 'Build').mkdir()
        (checkout / 'Build/cache').write_text('warm')
        (checkout / 'stray.o').write_text('junk')
        (checkout / 'main.v').write_text('edited in the release checkout\n')
        # Commits made after the clone, including older than the canonical tip, are fetched.
        git(self.root, 'commit', '-q', '-am', 'third')
        second = git(self.root, 'rev-parse', 'HEAD')
        git(self.root, 'commit', '-q', '--allow-empty', '-m', 'fourth')
        release.prepare_checkout(self.root, checkout, second)
        self.assertEqual(git(checkout, 'rev-parse', 'HEAD'), second)
        self.assertEqual(git(checkout, 'branch', '--show-current'), 'master')
        self.assertEqual((checkout / 'main.v').read_text(), 'work in progress\n')
        self.assertEqual((checkout / 'Build/cache').read_text(), 'warm')
        self.assertFalse((checkout / 'stray.o').exists())
        self.assertEqual(git(checkout, 'status', '--porcelain'), '')
        other = self.root.parent / 'occupied'
        other.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'not a release checkout'):
            release.prepare_checkout(self.root, other, second)
        with self.assertRaisesRegex(RuntimeError, 'is not on master'):
            release.prepare_checkout(self.root, checkout, '0' * 40)


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
                release.publish_release('owner/repo', '0.1.1', dmg, '15.0')
                self.assertEqual(commands[0][:6], ['gh', 'release', 'create', '0.1.1', str(dmg), '-R'])
                self.assertIn('macOS 15.0 or later', commands[0][commands[0].index('--notes') + 1])
                with self.assertRaisesRegex(RuntimeError, 'does not carry'):
                    release.publish_release('owner/repo', '0.1.1', dmg, '15.0')

    def test_site_download_must_redirect_to_the_uploaded_dmg(self):
        uploaded = 'https://github.com/owner/repo/releases/download/0.1.1/Vox-0.1.1-arm64.dmg'
        with patch.object(release, 'download_location', return_value=uploaded):
            release.check_download('owner/repo', '0.1.1', 'Vox-0.1.1-arm64.dmg')
            with self.assertRaisesRegex(RuntimeError, 'instead of .*Vox-0.1.1-x86_64.dmg.*--website-only'):
                release.check_download('owner/repo', '0.1.1', 'Vox-0.1.1-x86_64.dmg')
        with patch.object(release, 'download_location', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'redirects to None'):
                release.check_download('owner/repo', '0.1.1', 'Vox-0.1.1-arm64.dmg')

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
