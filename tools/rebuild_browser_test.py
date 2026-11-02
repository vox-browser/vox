from pathlib import Path
import json
from types import SimpleNamespace
import tempfile
import unittest
import sys
from unittest.mock import patch

import rebuild_browser as build


class ProductionBuildTests(unittest.TestCase):
    def test_repository_receipt_retains_docs_changes_without_invalidating_build_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'docs').mkdir()
            (root / 'main.v').write_text('module main')
            (root / 'resource.bin').write_bytes(b'engine resource')
            (root / 'docs/report.json').write_text('first report')
            def git(repo, *args):
                if args[0] == 'ls-files': return b'main.v\0docs/report.json\0resource.bin\0'
                if args[0] == 'rev-parse': return b'head'
                return b' M docs/report.json'
            with patch.object(build, 'git', side_effect=git):
                before = build.repository_state(root)
                (root / 'docs/report.json').write_text('updated evidence')
                after = build.repository_state(root)
                self.assertNotEqual(before['repository_sha256'], after['repository_sha256'])
                self.assertTrue(build.same_build_inputs(before, after))
                (root / 'resource.bin').write_bytes(b'changed engine resource')
                resource_change = build.repository_state(root)
                self.assertFalse(build.same_build_inputs(after, resource_change))
                (root / 'main.v').write_text('module main\nfn main() {}')
                self.assertFalse(build.same_build_inputs(resource_change, build.repository_state(root)))

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_docs_commit_during_compile_publishes_once_with_both_repository_receipts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'old')
            request = root / 'Build/production-build/request.json'
            build.write_json(request, dict(id='one'))
            calls = []
            def compile(repo, stage, receipt, environment):
                calls.append(stage)
                self.app(stage, b'compiled engine')
                build.write_json(request, dict(id='docs-commit'))
                return 0
            before = dict(head='one', repository_sha256='before-docs', build_inputs_sha256='same')
            after = dict(head='docs', repository_sha256='after-docs', build_inputs_sha256='same')
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', side_effect=[before, after, after]):
                self.assertEqual(build.build_pending(root, compile), 0)
            self.assertEqual(len(calls), 1)
            self.assertEqual(old.read_bytes(), b'compiled engine')
            receipt = json.loads((root / 'Build/production-build/latest.json').read_text())
            self.assertEqual(receipt['inputs'], before)
            self.assertEqual(receipt['verified_inputs'], after)

    def app(self, root, contents):
        executable = root / 'Vox.app/Contents/MacOS/Vox'
        executable.parent.mkdir(parents=True)
        executable.write_bytes(contents)
        return executable

    def test_failed_build_preserves_previous_bundle_and_removes_temporary_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'last successful build')
            build.write_json(root / 'Build/production-build/request.json', dict(id='one'))
            stages = []

            def fail(repo, stage, receipt, environment):
                self.assertEqual(repo, root)
                stages.append(stage)
                self.app(stage, b'partial')
                return 7

            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', return_value=dict(head='one')):
                self.assertEqual(build.build_pending(root, fail), 7)
            self.assertEqual(old.read_bytes(), b'last successful build')
            self.assertTrue(all(not stage.exists() for stage in stages))
            self.assertFalse((root / 'Build/production-build/latest.json').exists())

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_changed_source_is_rebuilt_and_only_the_latest_complete_bundle_is_published(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'old')
            request = root / 'Build/production-build/request.json'
            build.write_json(request, dict(id='one'))
            calls = []

            def compile(repo, stage, receipt, environment):
                self.assertEqual(repo, root)
                self.assertFalse((stage / 'main.v').exists())
                calls.append(stage)
                self.app(stage, str(len(calls)).encode())
                if len(calls) == 1:
                    build.write_json(request, dict(id='two'))
                return 0

            states = [dict(head='one'), dict(head='two'), dict(head='two'), dict(head='two')]
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', side_effect=states), \
                    patch('shutil.copytree', side_effect=AssertionError('source must not be copied')):
                self.assertEqual(build.build_pending(root, compile), 0)
            self.assertEqual(len(calls), 2)
            self.assertEqual(old.read_bytes(), b'2')
            self.assertTrue(all(not stage.exists() for stage in calls))

    def test_busy_build_does_not_start_another_compiler(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with build.lock(root / 'Build/production-build/build.lock'), \
                    patch.object(build, 'validate_repository'):
                self.assertEqual(build.build_pending(root, foreground=True), 75)
                self.assertEqual(build.build_pending(root), 0)

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_new_commit_is_not_lost_when_the_previous_build_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'old')
            request = root / 'Build/production-build/request.json'
            build.write_json(request, dict(id='one'))
            calls = []

            def compile(repo, stage, receipt, environment):
                calls.append(stage)
                if len(calls) == 1:
                    build.write_json(request, dict(id='two'))
                    return 1
                self.app(stage, b'new commit')
                return 0

            states = [dict(head='one'), dict(head='two'), dict(head='two')]
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', side_effect=states):
                self.assertEqual(build.build_pending(root, compile), 0)
            self.assertEqual(old.read_bytes(), b'new commit')

    def test_auto_build_drops_measurement_overrides_and_keeps_dependency_locations(self):
        env = dict(PATH='bin', V_BIN='/compiler/v', GIT_DIR='other', VOX_PRIVATE_GRAPHITE_HELPER='probe',
                   VOX_PHASE_DIAGNOSTICS='1', LADYBIRD_V_PROFILE='trace',
                   LADYBIRD_SOURCE_DIR='/upstream', LADYBIRD_VCPKG_TRIPLET='arm64-osx-dynamic')
        cleaned = build.production_environment(env)
        self.assertEqual(cleaned, {k: env[k] for k in ('PATH', 'V_BIN', 'LADYBIRD_SOURCE_DIR',
                                                      'LADYBIRD_VCPKG_TRIPLET')})

    def test_hook_installation_is_idempotent_and_preserves_custom_hooks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'git', return_value=b'.git/hooks/post-commit\n'):
                build.install_hook(root)
                build.install_hook(root)
                hook = root / '.git/hooks/post-commit'
                self.assertEqual(hook.read_text(), build.HOOK)
                self.assertTrue(hook.stat().st_mode & 0o111)
                hook.write_text('custom hook\n')
                with self.assertRaisesRegex(RuntimeError, 'Existing post-commit hook retained'):
                    build.install_hook(root)
                self.assertEqual(hook.read_text(), 'custom hook\n')

    def test_build_and_fresh_smoke_run_through_separate_memory_guards(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt = root / 'stage', root / 'receipt'
            receipt.mkdir()
            with patch.object(build.subprocess, 'run', return_value=SimpleNamespace(returncode=0)) as run:
                self.assertEqual(build.run_build(root, stage, receipt, {}), 0)
            first, second = run.call_args_list
            self.assertIn('run_memory_bounded.py', first.args[0][1])
            self.assertNotIn('--limit-gib', first.args[0])
            self.assertIn('--headless-smoke', second.args[0])
            self.assertEqual(second.args[0][second.args[0].index('--limit-gib') + 1], '3')
            self.assertEqual(first.kwargs['cwd'], root)
            self.assertEqual(first.kwargs['env']['VOX_BUILD_OUTPUT_DIR'], str(stage))


if __name__ == '__main__':
    unittest.main()
