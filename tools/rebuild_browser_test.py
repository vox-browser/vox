from pathlib import Path
import hashlib
import json
import os
from types import SimpleNamespace
import tempfile
import unittest
import sys
import subprocess
from unittest.mock import patch

import rebuild_browser as build


class ProductionBuildTests(unittest.TestCase):
    def test_explicit_pending_legacy_request_survives_automatic_requests(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);state=root/'Build/production-build'
            with patch.object(build,'validate_repository'), patch.object(build,'git',return_value=b'head'):
                build.enqueue(root,background=False,renderer='skia')
                build.enqueue(root,background=False)
                pending=json.loads((state/'request.json').read_text())
                self.assertEqual(pending['renderer'],'skia')
                build.write_json(state/'started.json',dict(id=pending['id']))
                build.enqueue(root,background=False)
                self.assertEqual(json.loads((state/'request.json').read_text())['renderer'],'gg')

    @unittest.skipUnless(sys.platform=='darwin','macOS application-directory publication')
    def test_renderer_change_is_not_lost_when_source_inputs_are_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);self.app(root/'Build/v',b'old')
            state=root/'Build/production-build'
            build.write_json(state/'request.json',dict(id='one',renderer='gg'))
            modes=[]
            def compile(repo,stage,receipt,environment):
                mode=environment['VOX_USE_SKIA'];modes.append(mode)
                self.app(stage,mode.encode())
                build.write_json(receipt/'renderer.json',dict(default='skia' if mode=='1' else 'gg',skia_free=False))
                if len(modes)==1:
                    build.write_json(state/'request.json',dict(id='two',renderer='skia'))
                return 0
            with patch.object(build,'validate_repository'), patch.object(build,'repository_state',return_value=dict(head='same')):
                self.assertEqual(build.build_pending(root,compile),0)
            self.assertEqual(modes,['0','1'])
            result=json.loads((state/'latest.json').read_text())
            self.assertEqual(result['renderer']['default'],'skia')
            self.assertFalse(result['renderer']['skia_free'])

    def test_literal_prod_request_survives_automatic_requests_and_can_be_reset(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); state=root/'Build/production-build'
            with patch.object(build,'validate_repository'), patch.object(build,'git',return_value=b'head'):
                build.enqueue(root,background=False,c_mode='single',v_prod=True)
                first=json.loads((state/'request.json').read_text())
                build.write_json(state/'started.json',dict(id=first['id']))
                build.enqueue(root,background=False)
                automatic=json.loads((state/'request.json').read_text())
                self.assertTrue(automatic['v_prod'])
                self.assertEqual(automatic['c_mode'],'single')
                build.enqueue(root,background=False,c_mode='parallel',v_prod=True)
                first=json.loads((state/'request.json').read_text())
                build.write_json(state/'started.json',dict(id=first['id']))
                build.enqueue(root,background=False)
                automatic=json.loads((state/'request.json').read_text())
                self.assertTrue(automatic['v_prod'])
                self.assertEqual(automatic['c_mode'],'parallel')
                build.enqueue(root,background=False,c_mode='parallel',v_prod=False)
                reset=json.loads((state/'request.json').read_text())
                self.assertFalse(reset['v_prod'])
                self.assertEqual(reset['c_mode'],'parallel')

    @unittest.skipUnless(sys.platform=='darwin','macOS application-directory publication')
    def test_literal_prod_request_reaches_the_supervised_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); self.app(root/'Build/v',b'old')
            build.write_json(root/'Build/production-build/request.json',dict(id='prod',c_mode='single',v_prod=True))
            def compile(repo,stage,receipt,environment):
                self.assertEqual(environment['VOX_BUILD_C_MODE'],'single')
                self.assertEqual(environment['VOX_BUILD_V_PROD'],'1')
                self.app(stage,b'prod'); return 0
            with patch.object(build,'validate_repository'), patch.object(build,'repository_state',return_value=dict(head='one')):
                self.assertEqual(build.build_pending(root,compile),0)
            self.assertTrue(json.loads((root/'Build/production-build/latest.json').read_text())['request']['v_prod'])

    def test_shell_prod_option_forwards_both_options_in_either_order(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); executable=root/'python3'; capture=root/'args'
            executable.write_text('#!/bin/sh\nprintf \'%s\\n\' "$@" > "$VOX_TEST_CAPTURE_ARGS"\n')
            executable.chmod(0o755)
            environment=dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'],
                             VOX_BUILD_SUPERVISED='0',VOX_TEST_CAPTURE_ARGS=str(capture))
            script=build.ROOT/'build-prod-browser.sh'
            for options in [('--prod',),('--prod','--no-parallel-cc'),('--no-parallel-cc','--prod')]:
                subprocess.run(['sh',str(script),*options],env=environment,check=True)
                self.assertEqual(capture.read_text().splitlines(),
                                 [str(build.ROOT/'tools/rebuild_browser.py'),'--build','--no-parallel-cc','--prod'])
            for options in [('--prod','--parallel-cc'),('--parallel-cc','--prod')]:
                subprocess.run(['sh',str(script),*options],env=environment,check=True)
                self.assertEqual(capture.read_text().splitlines(),
                                 [str(build.ROOT/'tools/rebuild_browser.py'),'--build','--parallel-cc','--prod'])

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_verified_frozen_compile_can_publish_its_pinned_source_after_later_edits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'old')
            build.write_json(root / 'Build/production-build/request.json', dict(id='one'))
            before = dict(head='one', build_inputs_sha256='compiled-source')
            after = dict(head='later', build_inputs_sha256='later-source')
            def compile(repo, stage, receipt, environment):
                self.assertEqual(json.loads((receipt / 'inputs-before.json').read_text()), before)
                self.app(stage, b'frozen compiled engine')
                build.write_json(receipt / 'frozen-compile.json', dict(protocol='fixture'))
                return 0
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', side_effect=[before, after]), \
                    patch('freeze_browser_compile.validate', return_value=dict(source_inputs=before)) as validate:
                self.assertEqual(build.build_pending(root, compile), 0)
            validate.assert_called_once()
            self.assertEqual(old.read_bytes(), b'frozen compiled engine')
            receipt = json.loads((root / 'Build/production-build/latest.json').read_text())
            self.assertEqual(receipt['verified_inputs'], before)
            self.assertEqual(receipt['repository_after_build'], after)

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_new_request_during_frozen_compilation_is_not_lost_after_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.app(root / 'Build/v', b'old')
            request = root / 'Build/production-build/request.json'
            build.write_json(request, dict(id='one'))
            one, two = dict(head='one', build_inputs_sha256='one'), dict(head='two', build_inputs_sha256='two')
            calls = []
            def compile(repo, stage, receipt, environment):
                calls.append(stage)
                self.app(stage, str(len(calls)).encode())
                build.write_json(receipt / 'frozen-compile.json', {})
                build.write_json(request, dict(id='two'))
                return 0
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', side_effect=[one, two, two, two, two]), \
                    patch('freeze_browser_compile.validate', side_effect=lambda receipt, expected: dict(source_inputs=expected)):
                self.assertEqual(build.build_pending(root, compile), 0)
            self.assertEqual(len(calls), 2)

    def test_invalid_frozen_inputs_keep_the_completed_bundle_and_failure_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'old')
            build.write_json(root / 'Build/production-build/request.json', dict(id='one'))
            def compile(repo, stage, receipt, environment):
                self.app(stage, b'changed inputs')
                build.write_json(receipt / 'frozen-compile.json', {})
                return 0
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', return_value=dict(head='one')), \
                    patch('freeze_browser_compile.validate', side_effect=RuntimeError('changed linker input')):
                self.assertEqual(build.build_pending(root, compile), 1)
            self.assertEqual(old.read_bytes(), b'old')
            receipt = next((root / 'Build/production-build/receipts').glob('*/result.json'))
            self.assertIn('changed linker input', json.loads(receipt.read_text())['frozen_input_error'])

    def test_worker_handoff_does_not_enqueue_or_hold_the_build_lock_for_the_successor(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'Build/production-build'
            def successor(repo):
                with build.lock(state / 'build.lock', nonblocking=True) as available:
                    self.assertIsNotNone(available)
                return 17
            with patch.object(build, 'build_pending', side_effect=successor), \
                    patch.object(build, 'enqueue', side_effect=AssertionError('no new request')):
                self.assertEqual(build.worker_after_current(root), 17)
            with build.lock(state / build.WORKER_UPGRADE_LOCK), patch.object(build, 'build_pending') as compiler:
                self.assertEqual(build.worker_after_current(root), 0)
                compiler.assert_not_called()

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_new_request_survives_a_rejected_frozen_input_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'old')
            request = root / 'Build/production-build/request.json'
            build.write_json(request, dict(id='one'))
            one, two = dict(head='one', build_inputs_sha256='one'), dict(head='two', build_inputs_sha256='two')
            calls = []
            def compile(repo, stage, receipt, environment):
                calls.append(stage)
                self.app(stage, str(len(calls)).encode())
                build.write_json(receipt / 'frozen-compile.json', {})
                build.write_json(request, dict(id='two'))
                return 0
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', side_effect=[one, two, two, two]), \
                    patch('freeze_browser_compile.validate', side_effect=[RuntimeError('changed library'), dict(source_inputs=two)]):
                self.assertEqual(build.build_pending(root, compile), 0)
            self.assertEqual(len(calls), 2)
            self.assertEqual(old.read_bytes(), b'2')

    def test_test_only_changes_preserve_build_inputs_and_remain_in_repository_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            test_inputs = [
                'Tests/Browser/Brave/input/banner.html',
                'Tests/Browser/Brave/expected/banner.png',
                'layout/banner_test.v',
                'tools/fixed_shadow_pixels_test.py',
                'tools/test_native_shadow.py',
                'tools/native_shadow_test.cpp',
                'tools/native_shadow_test.mm',
            ]
            runtime_inputs = [
                'main.v', 'layout/paint.v', 'layout/test_helpers.v',
                'native_browser_tab_titles_test_darwin.h',
                'tools/test_runtime_bridge.h', 'tools/native_runtime_test.h',
                'tools/build_mac_graphite.py',
                'tools/prepare_ui2.py', 'tools/adblock-worker-mini/main.v',
                'adblock/engine.snapshot.bin', 'packaging/Vox.entitlements.plist',
            ]
            names = test_inputs + runtime_inputs
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'original')
            def git(repo, *args):
                if args[0] == 'ls-files':
                    return b'\0'.join(name.encode() for name in names) + b'\0'
                if args[0] == 'rev-parse': return b'head'
                return b' M changed'
            with patch.object(build, 'git', side_effect=git):
                for name in names:
                    with self.subTest(path=name):
                        before = build.repository_state(root)
                        (root / name).write_bytes(b'changed')
                        after = build.repository_state(root)
                        self.assertNotEqual(before['repository_sha256'], after['repository_sha256'])
                        self.assertEqual(build.same_build_inputs(before, after), name in test_inputs)
                for name, ignored in [('tools/added_test.cpp', True), ('layout/added.v', False)]:
                    with self.subTest(added_path=name):
                        before = build.repository_state(root)
                        (root / name).write_bytes(b'new file')
                        names.append(name)
                        after = build.repository_state(root)
                        self.assertNotEqual(before['repository_sha256'], after['repository_sha256'])
                        self.assertEqual(build.same_build_inputs(before, after), ignored)
                        names.remove(name)
                        (root / name).unlink()
                        self.assertTrue(build.same_build_inputs(before, build.repository_state(root)))

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_reference_edit_during_compile_publishes_without_a_second_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = self.app(root / 'Build/v', b'old')
            fixture = root / 'Tests/Browser/expected.png'
            fixture.parent.mkdir(parents=True)
            fixture.write_bytes(b'old reference')
            request = root / 'Build/production-build/request.json'
            build.write_json(request, dict(id='one'))
            calls = []
            def git(repo, *args):
                if args[0] == 'ls-files': return b'Tests/Browser/expected.png\0'
                if args[0] == 'rev-parse': return b'head'
                return b' M Tests/Browser/expected.png'
            def compile(repo, stage, receipt, environment):
                calls.append(stage)
                self.app(stage, b'compiled engine')
                fixture.write_bytes(b'new reference')
                build.write_json(request, dict(id='reference-edit'))
                return 0
            with patch.object(build, 'validate_repository'), patch.object(build, 'git', side_effect=git):
                self.assertEqual(build.build_pending(root, compile), 0)
            self.assertEqual(len(calls), 1)
            self.assertEqual(old.read_bytes(), b'compiled engine')
            receipt = json.loads((root / 'Build/production-build/latest.json').read_text())
            self.assertNotEqual(receipt['inputs']['repository_sha256'],
                                receipt['verified_inputs']['repository_sha256'])
            self.assertTrue(build.same_build_inputs(receipt['inputs'], receipt['verified_inputs']))

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
                check = root / '.git/hooks/pre-commit'
                self.assertEqual(hook.read_text(), build.HOOK)
                self.assertEqual(check.read_text(), build.PRE_COMMIT_HOOK)
                self.assertTrue(hook.stat().st_mode & 0o111)
                self.assertTrue(check.stat().st_mode & 0o111)
                hook.write_text('custom hook\n')
                with self.assertRaisesRegex(RuntimeError, 'Existing post-commit hook retained'):
                    build.install_hook(root)
                self.assertEqual(hook.read_text(), 'custom hook\n')
                hook.write_text(build.HOOK)
                check.write_text('custom check\n')
                with self.assertRaisesRegex(RuntimeError, 'Existing pre-commit hook retained'):
                    build.install_hook(root)
                self.assertEqual(check.read_text(), 'custom check\n')

    def test_build_and_fresh_smoke_run_through_separate_memory_guards(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt = root / 'stage', root / 'receipt'
            receipt.mkdir()
            script = root / ('build-linux-browser.sh' if sys.platform == 'linux' else 'build-prod-browser.sh')
            script.write_text('exit 0\n')
            with patch.object(build.subprocess, 'run', return_value=SimpleNamespace(returncode=0)) as run:
                self.assertEqual(build.run_build(root, stage, receipt, {}), 0)
            first, second = run.call_args_list
            self.assertIn('run_memory_bounded.py', first.args[0][1])
            self.assertNotIn('--limit-gib', first.args[0])
            self.assertEqual(first.args[0][first.args[0].index('--timeout') + 1], '2700')
            self.assertIn('--headless-smoke', second.args[0])
            self.assertNotIn('--timeout', second.args[0])
            self.assertEqual(second.args[0][second.args[0].index('--limit-gib') + 1], '3')
            self.assertEqual(first.kwargs['cwd'], root)
            self.assertEqual(first.kwargs['env']['VOX_BUILD_OUTPUT_DIR'], str(stage))

    def test_build_uses_one_complete_script_after_the_file_is_edited(self):
        real_run = subprocess.run
        with tempfile.TemporaryDirectory(prefix="vox script's path ") as directory:
            root = Path(directory)
            stage, receipt = root / 'stage', root / 'receipt'
            stage.mkdir()
            receipt.mkdir()
            script = root / ('build-linux-browser.sh' if sys.platform == 'linux' else 'build-prod-browser.sh')
            original = b'''set -eu
printf '%s' "$0" > "$VOX_BUILD_OUTPUT_DIR/path"
printf '%s' 'quoted "body" with $literal and `literal`' > "$VOX_BUILD_OUTPUT_DIR/body"
'''
            script.write_bytes(original)
            calls = []
            def launch(command, **kwargs):
                calls.append(command)
                if len(calls) == 1:
                    # An unfinished editor write must not change the running
                    # build, nor be published as unchanged canonical source.
                    script.write_text('echo "unfinished edit\n')
                    guarded_command = command[command.index('--') + 1:]
                    return real_run(guarded_command, **kwargs)
                return SimpleNamespace(returncode=0)
            with patch.object(build.subprocess, 'run', side_effect=launch):
                self.assertEqual(build.run_build(root, stage, receipt, {}), 0)
            self.assertEqual((stage / 'path').read_text(), str(script))
            self.assertEqual((stage / 'body').read_text(), 'quoted "body" with $literal and `literal`')
            self.assertEqual(len(calls), 2)
            identity = json.loads((receipt / 'build-script.json').read_text())
            self.assertEqual(identity['sha256'], hashlib.sha256(original).hexdigest())
            self.assertEqual(identity['bytes'], len(original))
            self.assertFalse(any(p.suffix == '.sh' for p in receipt.iterdir()))
            self.assertFalse(any(p.suffix == '.sh' for p in stage.iterdir()))

    def test_script_stdin_reaches_the_build_through_the_real_memory_guard(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt = root / 'stage', root / 'receipt'
            receipt.mkdir()
            (root / 'tools').mkdir()
            (root / 'tools/run_memory_bounded.py').symlink_to(
                Path(build.__file__).resolve().with_name('run_memory_bounded.py'))
            script = root / ('build-linux-browser.sh' if sys.platform == 'linux' else 'build-prod-browser.sh')
            executable = stage / ('vox' if sys.platform == 'linux' else 'Vox.app/Contents/MacOS/Vox')
            script.write_text('set -eu\nmkdir -p "' + str(executable.parent) + '"\n'
                'cat > "' + str(executable) + '" <<\'SMOKE\'\n#!/bin/sh\n'
                'test "$1" = --headless-smoke\nSMOKE\nchmod +x "' + str(executable) + '"\n')
            self.assertEqual(build.run_build(root, stage, receipt, {}), 0)
            for name in ['memory.json', 'smoke-memory.json']:
                evidence = json.loads((receipt / name).read_text())
                self.assertEqual(evidence['reason'], 'completed')
                self.assertEqual(evidence['child_exit_code'], 0)
                self.assertEqual(evidence['limit_bytes'],
                                 (12 if name == 'memory.json' else 3) * 1024 ** 3)


    @unittest.skipUnless(sys.platform == 'darwin', 'macOS application-directory publication')
    def test_single_unit_request_reaches_the_build_and_its_published_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.app(root / 'Build/v', b'old')
            build.write_json(root / 'Build/production-build/request.json', dict(id='one', c_mode='single'))
            def compile(repo, stage, receipt, environment):
                self.assertEqual(environment['VOX_BUILD_C_MODE'], 'single')
                build.write_json(receipt / 'c-compile.json', dict(mode='single', requested='single'))
                self.app(stage, b'single unit')
                return 0
            state = dict(head='one', build_inputs_sha256='one')
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', return_value=state):
                self.assertEqual(build.build_pending(root, compile), 0)
            latest = json.loads((root / 'Build/production-build/latest.json').read_text())
            self.assertEqual(latest['c_compile'], dict(mode='single', requested='single'))
            started = json.loads((root / 'Build/production-build/started.json').read_text())
            self.assertEqual(started['id'], 'one')

    def test_requests_without_a_mode_build_parallel_c(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            build.write_json(root / 'Build/production-build/request.json', dict(id='one'))
            modes = []
            def compile(repo, stage, receipt, environment):
                modes.append(environment['VOX_BUILD_C_MODE'])
                return 1
            state = dict(head='one', build_inputs_sha256='one')
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'repository_state', return_value=state):
                self.assertEqual(build.build_pending(root, compile), 1)
            self.assertEqual(modes, ['parallel'])

    def test_automatic_requests_keep_a_single_unit_request_until_a_build_starts_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'Build/production-build'
            def request():
                return json.loads((state / 'request.json').read_text())
            with patch.object(build, 'validate_repository'), \
                    patch.object(build, 'git', return_value=b'head\n'):
                build.enqueue(root, background=False)
                self.assertEqual(request()['c_mode'], 'parallel')
                build.enqueue(root, background=False, c_mode='single')
                build.enqueue(root, background=False)
                self.assertEqual(request()['c_mode'], 'single')
                build.write_json(state / 'started.json', dict(id=request()['id']))
                build.enqueue(root, background=False)
                self.assertEqual(request()['c_mode'], 'parallel')
                build.enqueue(root, background=False, c_mode='single')
                build.enqueue(root, background=False, c_mode='parallel')
                self.assertEqual(request()['c_mode'], 'parallel')

    def test_single_unit_flag_is_only_accepted_for_builds(self):
        tool = Path(build.__file__)
        result = subprocess.run([sys.executable, str(tool), '--request', '--no-parallel-cc'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('--no-parallel-cc requires --build', result.stderr)
        result = subprocess.run([sys.executable, str(tool), '--request', '--prod'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('--prod requires --build', result.stderr)
        script = tool.parents[1] / 'build-prod-browser.sh'
        for arguments in (['--parallel'], ['--no-parallel-cc', '--no-parallel-cc'], ['--prod', '--prod'],
                          ['--parallel-cc','--parallel-cc'], ['--parallel-cc','--no-parallel-cc']):
            result = subprocess.run(['sh', str(script), *arguments], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('usage: build-prod-browser.sh [--no-parallel-cc | --parallel-cc]', result.stderr)


if __name__ == '__main__':
    unittest.main()
