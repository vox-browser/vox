import shlex
import unittest
from pathlib import Path

from dev_build_env import build_flags, shell_environment


class DevelopmentBuildEnvironmentTests(unittest.TestCase):
    def test_paths_with_spaces_remain_one_compiler_argument(self):
        flags = shlex.split(build_flags(Path('/my source/vox'), ['/my modules'], 'darwin'))
        self.assertEqual(flags[flags.index('-path') + 1], '/my source/vox|/my modules|@vmodules|@vlib')
        self.assertEqual(flags[:4], ['-b', 'c', '-enable-globals', '-memory-limit'])

    def test_linux_uses_native_dependencies_and_explicit_process_feature_macros(self):
        flags = shlex.split(build_flags(Path('/vox'), [], 'linux'))
        self.assertIn('dynamic_boehm', flags)
        self.assertIn('use_openssl', flags)
        self.assertEqual(flags[flags.index('-cflags') + 1], '-D_GNU_SOURCE=1')

    def test_windows_embeds_resources_and_selects_the_shared_ui2_renderer(self):
        flags = shlex.split(build_flags(Path('C:/vox'), [], 'win32'))
        for flag in ['-prod', '-no-prod-options', 'none', 'sokol_d3d11', 'ui2_custom_rendering']:
            self.assertIn(flag, flags)
        self.assertEqual(flags[flags.index('-cc') + 1], 'gcc')

    def test_shell_exports_preserve_quotes_and_literal_substitutions(self):
        values = {'VFLAGS': "a'b $(literal) `literal`"}
        sh = shell_environment(values, 'sh')
        self.assertEqual(shlex.split(sh.removeprefix('export '))[0], "VFLAGS=" + values['VFLAGS'])
        self.assertEqual(shell_environment(values, 'powershell'),
                         "$env:VFLAGS = 'a''b $(literal) `literal`'")


if __name__ == '__main__':
    unittest.main()
