import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest


class LinuxCompilerSelectionTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='vox-linux-build-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
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
        self.environment.update(
            PATH=str(self.helpers),
            HOME=str(self.test_home),
            LADYBIRD_V_GC='boehm',
            VOX_BUILD_TEST_COMPILER_LOG=str(self.compiler_log),
            VOX_BUILD_TEST_HELPER_LOG=str(self.helper_log),
            VOX_BUILD_TEST_MODULES=str(self.root / 'modules'),
        )
        # Run the real shell entrypoint, replacing only its external tools.
        # No native dependencies, compiler installation, or browser build is needed.
        self.write_executable(self.helpers / 'uname', "print('Linux')")
        self.write_executable(self.helpers / 'pkg-config', 'pass')
        self.write_executable(self.helpers / 'python3', '''
            import json
            import os
            from pathlib import Path
            import sys

            with open(os.environ['VOX_BUILD_TEST_HELPER_LOG'], 'a') as log:
                log.write(json.dumps({'argv': sys.argv[1:], 'cwd': os.getcwd()}) + '\\n')
            if Path(sys.argv[1]).name.startswith('prepare_'):
                print(os.environ['VOX_BUILD_TEST_MODULES'])
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

    def run_build(self, v_bin=None, path=None):
        environment = dict(self.environment)
        if v_bin is not None:
            environment['V_BIN'] = str(v_bin)
        if path is not None:
            environment['PATH'] = path
        return subprocess.run([self.shell, str(self.repo / 'build-linux-browser.sh')],
                              cwd=self.caller, env=environment, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              timeout=10)

    def assert_compiler_selected(self, result, compiler):
        self.assertEqual(result.returncode, 0, result.stdout)
        recorded = json.loads(self.compiler_log.read_text())
        self.assertEqual(recorded['executable'], str(compiler))
        self.assertEqual(recorded['cwd'], str(self.repo))
        self.assertEqual(recorded['argv'][-3:],
                         ['-o', str(self.repo / 'Build/linux/vox'), '.'])
        helpers = [json.loads(line) for line in self.helper_log.read_text().splitlines()]
        preparations = [item for item in helpers
                        if Path(item['argv'][0]).name.startswith('prepare_')]
        self.assertEqual(len(preparations), 2)
        for preparation in preparations:
            self.assertEqual(preparation['argv'][1], str(compiler))
            self.assertEqual(preparation['cwd'], str(self.caller))

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
