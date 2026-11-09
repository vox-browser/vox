import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

from rebuild_browser import BUILD_PROTOCOL


class LinuxCompilerSelectionTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='vox-linux-build-')
        self.addCleanup(self.temporary.cleanup)
        # The shell uses pwd -P; macOS exposes /var through /private/var.
        self.root = Path(self.temporary.name).resolve()
        self.repo = self.root / 'project'
        self.caller = self.root / 'caller'
        self.helpers = self.root / 'helpers'
        self.test_home = self.root / 'home'
        for directory in (self.repo, self.caller, self.helpers, self.test_home):
            directory.mkdir()
        self.shell = shutil.which('sh')
        self.assertIsNotNone(self.shell)
        for command in ('dirname', 'mkdir'):
            executable = shutil.which(command)
            self.assertIsNotNone(executable)
            (self.helpers / command).symlink_to(executable)
        shutil.copyfile(Path(__file__).resolve().parent.parent / 'build-linux-browser.sh',
                        self.repo / 'build-linux-browser.sh')
        self.compiler_log = self.root / 'compiler.json'
        self.helper_log = self.root / 'helpers.jsonl'
        self.environment = dict(os.environ)
        self.environment.pop('V_BIN', None)
        self.environment.pop('VOX_BUILD_OUTPUT_DIR', None)
        self.environment.update(
            PATH=str(self.helpers),
            HOME=str(self.test_home),
            LADYBIRD_V_GC='boehm',
            VOX_BUILD_SUPERVISED='1',
            VOX_BUILD_COMPILE_PROTOCOL=BUILD_PROTOCOL,
            VOX_BUILD_TEST_COMPILER_LOG=str(self.compiler_log),
            VOX_BUILD_TEST_HELPER_LOG=str(self.helper_log),
            VOX_BUILD_TEST_MODULES=str(self.root / 'modules'),
            VOX_BUILD_TEST_LINUX_MODULES=str(self.root / 'linux-modules'),
            VOX_BUILD_TEST_SHELL=self.shell,
            VOX_BUILD_TEST_REENTER='0',
        )
        # Run the real shell entrypoint, replacing only its external tools.
        # No native dependencies, compiler installation, or browser build is needed.
        self.write_executable(self.helpers / 'uname', "print('Linux')")
        self.write_executable(self.helpers / 'pkg-config', 'pass')
        self.write_executable(self.helpers / 'python3', '''
            import json
            import os
            from pathlib import Path
            import subprocess
            import sys

            with open(os.environ['VOX_BUILD_TEST_HELPER_LOG'], 'a') as log:
                log.write(json.dumps({'argv': sys.argv[1:], 'cwd': os.getcwd(),
                                      'v_bin': os.environ.get('V_BIN')}) + '\\n')
            if (Path(sys.argv[1]).name == 'rebuild_browser.py'
                    and sys.argv[2:] == ['--build']
                    and os.environ['VOX_BUILD_TEST_REENTER'] == '1'):
                # Model the supervisor's reentry from the repository directory.
                repo = Path(sys.argv[1]).parent.parent
                result = subprocess.run(
                    [os.environ['VOX_BUILD_TEST_SHELL'], str(repo / 'build-linux-browser.sh')],
                    cwd=repo, env=dict(os.environ, VOX_BUILD_SUPERVISED='1'))
                raise SystemExit(result.returncode)
            if Path(sys.argv[1]).name == 'prepare_linux_modules.py':
                print(os.environ['VOX_BUILD_TEST_LINUX_MODULES'])
            elif Path(sys.argv[1]).name.startswith('prepare_'):
                print(os.environ['VOX_BUILD_TEST_MODULES'])
            if Path(sys.argv[1]).name == 'browser_backend.py':
                print('fastc')
        ''')

    def write_executable(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'#!{sys.executable}\n' + textwrap.dedent(body).lstrip())
        path.chmod(0o755)
        return path

    def compiler(self, path):
        return self.write_executable(path, '''
            import json
            import os
            from pathlib import Path
            import sys

            Path(os.environ['VOX_BUILD_TEST_COMPILER_LOG']).write_text(json.dumps({
                'executable': sys.argv[0], 'argv': sys.argv[1:], 'cwd': os.getcwd(),
            }))
        ''')

    def run_build(self, v_bin=None, path=None, overrides=None):
        environment = dict(self.environment)
        if v_bin is not None:
            environment['V_BIN'] = str(v_bin)
        if path is not None:
            environment['PATH'] = path
        environment.update(overrides or {})
        return subprocess.run([self.shell, str(self.repo / 'build-linux-browser.sh')],
                              cwd=self.caller, env=environment, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              timeout=10)

    def assert_compiler_selected(self, result, compiler, helper_cwd=None):
        self.assertEqual(result.returncode, 0, result.stdout)
        recorded = json.loads(self.compiler_log.read_text())
        self.assertEqual(recorded['executable'], str(compiler))
        self.assertEqual(recorded['cwd'], str(self.repo))
        self.assertEqual(recorded['argv'][:2], ['-b', 'fastc'])
        self.assertEqual(recorded['argv'][-3:],
                         ['-o', str(self.repo / 'Build/linux/vox'), '.'])
        helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
        preparations = [item for item in helpers
                        if Path(item['argv'][0]).name.startswith('prepare_')]
        self.assertEqual([Path(item['argv'][0]).name for item in preparations],
                         ['prepare_http_compat.py', 'prepare_ui2.py', 'prepare_linux_modules.py'])
        for preparation in preparations:
            self.assertEqual(preparation['argv'][1], str(compiler))
            self.assertEqual(preparation['cwd'], str(helper_cwd or self.caller))
            self.assertEqual(preparation['argv'][2:], [])

    def test_unsupervised_build_delegates_to_supervisor(self):
        compiler = self.compiler(self.helpers / 'v')
        result = self.run_build(overrides={'VOX_BUILD_SUPERVISED': '0'})
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse(self.compiler_log.exists())
        helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
        self.assertEqual([item['argv'] for item in helpers],
                         [[str(self.repo / 'tools/rebuild_browser.py'), '--build']])
        self.assertEqual(helpers[0]['v_bin'], str(compiler))

    def test_current_ui2_precedes_a_stale_linux_module(self):
        compiler = self.compiler(self.helpers / 'v')
        current = self.root / 'current-ui2'
        current.mkdir()
        (current / 'ui.v').write_text('current UI2')
        modules = Path(self.environment['VOX_BUILD_TEST_MODULES'])
        modules.mkdir()
        (modules / 'ui2').symlink_to(current, target_is_directory=True)
        selected = modules / 'ui2/ui.v'
        stale = Path(self.environment['VOX_BUILD_TEST_LINUX_MODULES']) / 'ui2/ui.v'
        stale.parent.mkdir(parents=True)
        stale.write_text('obsolete UI2')
        result = self.run_build()
        self.assert_compiler_selected(result, compiler)
        arguments = json.loads(self.compiler_log.read_text())['argv']
        paths = arguments[arguments.index('-path') + 1].split('|')
        resolved = next(Path(path) / 'ui2/ui.v' for path in paths
                        if (Path(path) / 'ui2/ui.v').is_file())
        self.assertEqual(resolved, selected)
        (current / 'ui.v').write_text('updated UI2')
        self.assertEqual(resolved.read_text(), 'updated UI2')

    def test_unsupervised_relative_compiler_survives_supervisor_directory_change(self):
        compiler = self.compiler(self.caller / 'toolchain/v')
        result = self.run_build(v_bin='toolchain/v', overrides={
            'VOX_BUILD_SUPERVISED': '0', 'VOX_BUILD_TEST_REENTER': '1'})
        self.assert_compiler_selected(result, compiler, helper_cwd=self.repo)

    def test_unsupervised_relative_path_survives_supervisor_directory_change(self):
        compiler = self.compiler(self.caller / 'toolchain/v')
        result = self.run_build(path='toolchain' + os.pathsep + self.environment['PATH'],
                                overrides={'VOX_BUILD_SUPERVISED': '0',
                                           'VOX_BUILD_TEST_REENTER': '1'})
        self.assert_compiler_selected(result, compiler, helper_cwd=self.repo)

    def test_stale_supervisor_requests_upgrade_without_compiling(self):
        self.compiler(self.helpers / 'v')
        for protocol in ('', 'bundle-lease-v1'):
            with self.subTest(protocol=protocol):
                self.helper_log.unlink(missing_ok=True)
                result = self.run_build(overrides={'VOX_BUILD_COMPILE_PROTOCOL': protocol})
                self.assertEqual(result.returncode, 75, result.stdout)
                self.assertFalse(self.compiler_log.exists())
                helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
                self.assertEqual([item['argv'] for item in helpers],
                                 [[str(self.repo / 'tools/rebuild_browser.py'), '--upgrade-worker']])

    def test_current_supervisor_protocol_reaches_compiler(self):
        compiler = self.compiler(self.helpers / 'v')
        self.assert_compiler_selected(self.run_build(), compiler)

    def test_explicit_compiler_name_is_found_on_path(self):
        compiler = self.compiler(self.helpers / 'v')
        self.assert_compiler_selected(self.run_build(v_bin='v'), compiler)

    def test_explicit_compiler_takes_precedence_over_default_on_path(self):
        self.compiler(self.helpers / 'v')
        compiler = self.compiler(self.helpers / 'custom-v')
        self.assert_compiler_selected(self.run_build(v_bin='custom-v'), compiler)

    def test_caller_relative_compiler_survives_repository_directory_change(self):
        compiler = self.compiler(self.caller / 'toolchain/v')
        self.assert_compiler_selected(self.run_build(v_bin='toolchain/v'), compiler)

    def test_default_compiler_on_relative_path_survives_directory_change(self):
        compiler = self.compiler(self.caller / 'toolchain/v')
        path = 'toolchain' + os.pathsep + self.environment['PATH']
        self.assert_compiler_selected(self.run_build(path=path), compiler)

    def test_default_compiler_on_path_takes_precedence_over_home_fallback(self):
        self.compiler(self.test_home / 'code/v/v')
        compiler = self.compiler(self.helpers / 'v')
        self.assert_compiler_selected(self.run_build(), compiler)

    def test_default_compiler_uses_home_fallback_when_absent_from_path(self):
        compiler = self.compiler(self.test_home / 'code/v/v')
        self.assert_compiler_selected(self.run_build(), compiler)

    def test_absolute_compiler_path_preserves_spaces(self):
        compiler = self.compiler(self.root / 'compiler directory/v executable')
        self.assert_compiler_selected(self.run_build(v_bin=compiler), compiler)

    def test_compiler_symlink_is_not_dereferenced(self):
        target = self.compiler(self.root / 'compiler-target')
        compiler = self.caller / 'toolchain/v'
        compiler.parent.mkdir()
        compiler.symlink_to(target)
        self.assert_compiler_selected(self.run_build(v_bin='toolchain/v'), compiler)

    def test_missing_explicit_compiler_does_not_fall_back_to_path(self):
        self.compiler(self.helpers / 'v')
        result = self.run_build(v_bin='missing-v')
        self.assertEqual(result.returncode, 1)
        self.assertIn('V compiler not found', result.stdout)
        self.assertFalse(self.compiler_log.exists())
        self.assertFalse(self.helper_log.exists())

    def test_nonexecutable_explicit_compiler_does_not_fall_back_to_path(self):
        self.compiler(self.helpers / 'v')
        compiler = self.compiler(self.caller / 'not-executable')
        compiler.chmod(0o644)
        result = self.run_build(v_bin=compiler)
        self.assertEqual(result.returncode, 1)
        self.assertIn('V compiler not found', result.stdout)
        self.assertFalse(self.compiler_log.exists())
        self.assertFalse(self.helper_log.exists())


if __name__ == '__main__':
    unittest.main()
