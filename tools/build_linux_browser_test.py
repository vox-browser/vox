import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

REPO = Path(__file__).resolve().parent.parent
(BUILD_PROTOCOL,) = re.findall(
    r"(?m)^const build_protocol = '([^']+)'$",
    (REPO / 'tools/voxbuild/supervisor.v').read_text())


class LinuxCompilerSelectionTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='vox-linux-build-')
        self.addCleanup(self.temporary.cleanup)
        # The shell uses pwd -P; macOS exposes /var through /private/var.
        self.root = Path(self.temporary.name).resolve()
        self.repo = self.root / 'project with spaces'
        self.caller = self.root / 'caller with spaces'
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
        shutil.copyfile(REPO / 'build-linux-browser.sh',
                        self.repo / 'build-linux-browser.sh')
        self.compiler_log = self.root / 'compiler.json'
        self.helper_log = self.root / 'helpers.jsonl'
        self.environment = dict(os.environ)
        self.environment.pop('V_BIN', None)
        self.environment.pop('VOX_BUILD_OUTPUT_DIR', None)
        self.environment.pop('VOX_BUILD_BACKEND', None)
        self.environment.update(
            PATH=str(self.helpers),
            HOME=str(self.test_home),
            LADYBIRD_V_GC='boehm',
            VOX_BUILD_SUPERVISED='1',
            VOX_BUILD_COMPILE_PROTOCOL=BUILD_PROTOCOL,
            VOX_BUILD_TEST_COMPILER_LOG=str(self.compiler_log),
            VOX_BUILD_TEST_HELPER_LOG=str(self.helper_log),
            VOX_BUILD_TEST_MODULES=str(self.root / 'compatibility modules'),
            VOX_BUILD_TEST_PREALLOC_MODULES=str(self.root / 'prealloc runtime'),
            VOX_BUILD_TEST_PREALLOC_FAILURE='0',
            VOX_BUILD_TEST_LINUX_MODULES=str(self.root / 'linux modules'),
            VOX_BUILD_TEST_SHELL=self.shell,
            VOX_BUILD_TEST_REENTER='0',
            CC='clang',
            VOX_LINUX_CFLAGS='-O2',
        )
        # Run the real shell entrypoint, replacing only its external tools.
        # No native dependencies, compiler installation, or browser build is needed.
        # Test doubles use this harness's absolute interpreter. The build cannot
        # find Python by command name: those PATH entries fail deliberately.
        self.write_executable(self.helpers / 'uname', "print('Linux')")
        self.write_executable(self.helpers / 'pkg-config', 'pass')
        self.build_tool = self.write_executable(self.repo / 'tools/vox-build.sh', '''
            import json
            import os
            from pathlib import Path
            import subprocess
            import sys

            with open(os.environ['VOX_BUILD_TEST_HELPER_LOG'], 'a') as log:
                log.write(json.dumps({'executable': sys.argv[0], 'argv': sys.argv[1:], 'cwd': os.getcwd(),
                                      'v_bin': os.environ.get('V_BIN')}) + '\\n')
            if (sys.argv[1] == 'supervise'
                    and sys.argv[2:] == ['--build']
                    and os.environ['VOX_BUILD_TEST_REENTER'] == '1'):
                # Model the supervisor's reentry from the repository directory.
                repo = Path(sys.argv[0]).parent.parent
                result = subprocess.run(
                    [os.environ['VOX_BUILD_TEST_SHELL'], str(repo / 'build-linux-browser.sh')],
                    cwd=repo, env=dict(os.environ, VOX_BUILD_SUPERVISED='1'))
                raise SystemExit(result.returncode)
            if sys.argv[1] == 'prepare-prealloc':
                failure = int(os.environ['VOX_BUILD_TEST_PREALLOC_FAILURE'])
                if failure:
                    print('Unsupported V allocator', file=sys.stderr)
                    raise SystemExit(failure)
                print(os.environ['VOX_BUILD_TEST_PREALLOC_MODULES'])
            elif sys.argv[1] == 'prepare-linux-modules':
                print(os.environ['VOX_BUILD_TEST_LINUX_MODULES'])
            elif sys.argv[1] in ('prepare-http', 'prepare-ui2'):
                print(os.environ['VOX_BUILD_TEST_MODULES'])
            elif sys.argv[1] == 'backend':
                print('fastc')
            elif sys.argv[1] not in ('supervise', 'build-avif', 'build-native'):
                raise SystemExit('Unexpected native build command: ' + sys.argv[1])
        ''')
        for name in ('python', 'python3'):
            self.write_executable(self.helpers / name, '''
                import sys
                print('Unexpected Python invocation from the build entrypoint', file=sys.stderr)
                raise SystemExit(97)
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
        self.assertEqual(recorded['argv'][recorded['argv'].index('-gc') + 1], 'boehm')
        self.assertIn('dynamic_boehm', recorded['argv'])
        self.assertNotIn('-prealloc', recorded['argv'])
        helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
        preparations = [item for item in helpers
                        if item['argv'][0].startswith('prepare-')]
        self.assertEqual([item['argv'][0] for item in preparations],
                         ['prepare-http', 'prepare-ui2', 'prepare-linux-modules'])
        for preparation in preparations:
            self.assertEqual(preparation['executable'], str(self.build_tool))
            self.assertEqual(preparation['argv'][1], str(compiler))
            self.assertEqual(preparation['cwd'], str(helper_cwd or self.caller))
            self.assertEqual(preparation['argv'][2:], [])

    def assert_prealloc_selected(self, result, compiler, staged, backend='fastc',
                                helper_cwd=None):
        self.assertEqual(result.returncode, 0, result.stdout)
        recorded = json.loads(self.compiler_log.read_text())
        arguments = recorded['argv']
        self.assertEqual(recorded['executable'], str(staged))
        self.assertEqual(recorded['cwd'], str(staged.parent))
        self.assertEqual(arguments[:2], ['-b', backend])
        self.assertEqual(arguments[-3:],
                         ['-o', str(self.repo / 'Build/linux/vox'), str(self.repo)])
        self.assertEqual(arguments.count('-gc'), 1)
        self.assertEqual(arguments[arguments.index('-gc') + 1], 'none')
        for flag in ('-w', '-n', '-nocache', '-prealloc'):
            self.assertIn(flag, arguments)
        self.assertNotIn('dynamic_boehm', arguments)
        self.assertNotIn('-prod', arguments)
        self.assertEqual(arguments[arguments.index('-memory-limit') + 1], '10G')
        self.assertEqual(arguments[arguments.index('-cflags') + 1], '-D_GNU_SOURCE=1 -O2')
        paths = arguments[arguments.index('-path') + 1].split('|')
        self.assertEqual(paths[:2], [str(self.repo), str(staged.parent.parent)])
        self.assertEqual(paths[-2:], ['@vmodules', '@vlib'])
        helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
        preparations = [item for item in helpers
                        if item['argv'][0].startswith('prepare-')]
        self.assertEqual([item['argv'][0] for item in preparations],
                         ['prepare-http', 'prepare-ui2',
                          'prepare-linux-modules', 'prepare-prealloc'])
        for preparation in preparations:
            self.assertEqual(preparation['executable'], str(self.build_tool))
            self.assertEqual(preparation['argv'][1], str(compiler))
            self.assertEqual(preparation['cwd'], str(helper_cwd or self.caller))
        self.assertEqual(preparations[-1]['argv'][2],
                         str(self.repo / 'Build/linux/prealloc-runtime'))
        self.assertIn('Building Vox (prealloc)', result.stdout)

    def test_prealloc_uses_staged_compiler_and_no_collector(self):
        compiler = self.compiler(self.helpers / 'v')
        staged = self.compiler(Path(self.environment['VOX_BUILD_TEST_PREALLOC_MODULES']) / 'compiler/v')
        result = self.run_build(overrides={'LADYBIRD_V_GC': 'prealloc'})
        self.assert_prealloc_selected(result, compiler, staged)

    def test_prealloc_preserves_explicit_backend(self):
        compiler = self.compiler(self.helpers / 'v')
        staged = self.compiler(Path(self.environment['VOX_BUILD_TEST_PREALLOC_MODULES']) / 'compiler/v')
        result = self.run_build(overrides={'LADYBIRD_V_GC': 'prealloc', 'VOX_BUILD_BACKEND': 'c'})
        self.assert_prealloc_selected(result, compiler, staged, backend='c')

    def test_prealloc_compiler_survives_supervisor_directory_change(self):
        compiler = self.compiler(self.caller / 'toolchain/v')
        staged = self.compiler(Path(self.environment['VOX_BUILD_TEST_PREALLOC_MODULES']) / 'compiler/v')
        result = self.run_build(v_bin='toolchain/v', overrides={
            'LADYBIRD_V_GC': 'prealloc', 'VOX_BUILD_SUPERVISED': '0',
            'VOX_BUILD_TEST_REENTER': '1'})
        self.assert_prealloc_selected(result, compiler, staged, helper_cwd=self.repo)

    def test_prealloc_staging_failure_does_not_fall_back_to_original_compiler(self):
        self.compiler(self.helpers / 'v')
        self.compiler(Path(self.environment['VOX_BUILD_TEST_PREALLOC_MODULES']) / 'compiler/v')
        result = self.run_build(overrides={
            'LADYBIRD_V_GC': 'prealloc', 'VOX_BUILD_TEST_PREALLOC_FAILURE': '23'})
        self.assertEqual(result.returncode, 23, result.stdout)
        self.assertIn('Unsupported V allocator', result.stdout)
        self.assertFalse(self.compiler_log.exists())

    def test_unknown_allocator_is_rejected_before_building(self):
        self.compiler(self.helpers / 'v')
        result = self.run_build(overrides={'LADYBIRD_V_GC': 'unknown'})
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('boehm, boehm_full, prealloc, or none', result.stdout)
        self.assertFalse(self.compiler_log.exists())
        self.assertFalse(self.helper_log.exists())

    def test_unsupervised_build_delegates_to_supervisor(self):
        compiler = self.compiler(self.helpers / 'v')
        result = self.run_build(overrides={'VOX_BUILD_SUPERVISED': '0'})
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse(self.compiler_log.exists())
        helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
        self.assertEqual([item['argv'] for item in helpers],
                         [['supervise', '--build']])
        self.assertEqual(helpers[0]['v_bin'], str(compiler))

    def test_current_ui2_precedes_a_stale_linux_module(self):
        compiler = self.compiler(self.helpers / 'v')
        staged = self.compiler(Path(self.environment['VOX_BUILD_TEST_PREALLOC_MODULES']) / 'compiler/v')
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
        for gc in ('boehm', 'prealloc'):
            with self.subTest(gc=gc):
                self.helper_log.unlink(missing_ok=True)
                result = self.run_build(overrides={'LADYBIRD_V_GC': gc})
                if gc == 'prealloc':
                    self.assert_prealloc_selected(result, compiler, staged)
                else:
                    self.assert_compiler_selected(result, compiler)
                arguments = json.loads(self.compiler_log.read_text())['argv']
                paths = arguments[arguments.index('-path') + 1].split('|')
                resolved = next(Path(path) / 'ui2/ui.v' for path in paths
                                if (Path(path) / 'ui2/ui.v').is_file())
                self.assertEqual(resolved, selected)
                (current / 'ui.v').write_text(f'updated UI2 for {gc}')
                self.assertEqual(resolved.read_text(), f'updated UI2 for {gc}')

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
                                 [['supervise', '--upgrade-worker']])

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

    def test_native_build_tool_preserves_spaced_repository_and_argument_paths(self):
        compiler = self.compiler(self.root / 'selected toolchain/v compiler')
        self.assert_compiler_selected(self.run_build(v_bin=compiler), compiler)
        helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
        self.assertTrue(all(item['executable'] == str(self.build_tool) for item in helpers))
        self.assertEqual([item['argv'][0] for item in helpers],
                         ['build-avif', 'build-native', 'prepare-http', 'prepare-ui2',
                          'prepare-linux-modules', 'backend'])
        self.assertEqual(helpers[0]['argv'],
                         ['build-avif', '--output', str(self.repo / 'Build/linux/libVoxAVIF.so')])
        self.assertEqual(helpers[-1]['argv'], ['backend', str(self.repo)])
        arguments = json.loads(self.compiler_log.read_text())['argv']
        paths = arguments[arguments.index('-path') + 1].split('|')
        self.assertEqual(paths[:4], [str(self.repo), self.environment['VOX_BUILD_TEST_MODULES'],
                                     self.environment['VOX_BUILD_TEST_LINUX_MODULES'],
                                     self.environment['VOX_BUILD_TEST_MODULES']])

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


class NativeBuildEntrypointTest(unittest.TestCase):
    def test_normal_build_entrypoints_do_not_invoke_python(self):
        for name in ('build-linux-browser.sh', 'build-prod-browser.sh',
                     'tools/vox-build.sh', 'build_browser.vsh'):
            with self.subTest(entrypoint=name):
                code = '\n'.join(line for line in (REPO / name).read_text().splitlines()
                                 if not line.lstrip().startswith(('#', '//')))
                self.assertNotRegex(code, r'(?i)\bpython(?:[23](?:\.\d+)*)?\b')
                self.assertNotRegex(code, r'[\w/.-]+\.py\b')


if __name__ == '__main__':
    unittest.main()
