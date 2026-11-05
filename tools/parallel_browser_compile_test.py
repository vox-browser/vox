#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).with_name('parallel_browser_compile.py')

FAKE_COMPILER = '''#!/bin/sh
{marker}
printf '%s\\n' "$@" > "$FAKE_DIR/args"
printf '%s' "$(printenv "$FAKE_REQUIRE_VARIABLE")" > "$FAKE_DIR/require_split"
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then output=$2; fi
    shift
done
case "$FAKE_MODE" in
    split)
        echo 'parallel C: 33 units; the first also compiles the functions of 22 of 130 body parts'
        echo binary > "$output" ;;
    refuse)
        echo 'parallel C: compiling one C unit, because the native code would change if every unit compiled it:'
        echo '  /repo/platform/state.h:3: mutable static storage'
        echo partial > "$output"
        echo "error: -parallel-cc cannot split this program into C units ($FAKE_REQUIRE_VARIABLE is set; the reasons are listed above)"
        exit 3 ;;
    fail)
        echo 'main.v:1:1: error: unexpected token'
        exit 1 ;;
    silent) ;;
esac
'''


class ParallelBrowserCompileTests(unittest.TestCase):
    def run_tool(self, mode, supported=True):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        compiler = root / 'v'
        marker = '# V3_PARALLEL_CC_REQUIRE_SPLIT' if supported else '# stock driver'
        compiler.write_text(FAKE_COMPILER.format(marker=marker))
        compiler.chmod(0o755)
        receipt, output = root / 'receipt', root / 'out/Vox'
        output.parent.mkdir()
        # The variable is named indirectly so that only `marker` decides support.
        environment = dict(os.environ, FAKE_DIR=str(root), FAKE_MODE=mode,
                           FAKE_REQUIRE_VARIABLE='V3_PARALLEL_CC_REQUIRE_SPLIT')
        environment.pop('V3_PARALLEL_CC_REQUIRE_SPLIT', None)
        result = subprocess.run([sys.executable, str(TOOL), '--receipt', str(receipt),
                                 '--output', str(output), '--', str(compiler), '-b', 'c',
                                 '-cflags', '-O3 -flto=thin', '/repo'],
                                env=environment, capture_output=True, text=True)
        record = json.loads((receipt / 'c-compile.json').read_text())
        return root, result, record, output

    def test_split_build_links_the_output_and_records_its_units(self):
        root, result, record, output = self.run_tool('split')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(output.is_file())
        self.assertEqual(record['mode'], 'parallel')
        self.assertEqual(record['units'], 33)
        self.assertIn('parallel C: 33 units', result.stdout)
        args = (root / 'args').read_text().splitlines()
        self.assertEqual(args, ['-b', 'c', '-cflags', '-O3 -flto=thin', '-parallel-cc', '-o',
                                str(output), '/repo'])
        self.assertEqual((root / 'require_split').read_text(), '1')

    def test_refused_split_leaves_no_output_and_records_the_reasons(self):
        _, result, record, output = self.run_tool('refuse')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(output.exists())
        self.assertEqual(record['mode'], 'single')
        self.assertEqual(record['requested'], 'parallel')
        self.assertIn('/repo/platform/state.h:3: mutable static storage', record['reasons'])
        self.assertIn('compiling one C unit', result.stdout)

    def test_compiler_without_split_support_is_not_run(self):
        root, result, record, output = self.run_tool('split', supported=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((root / 'args').exists())
        self.assertFalse(output.exists())
        self.assertEqual(record['mode'], 'single')
        self.assertIn('V3_PARALLEL_CC_REQUIRE_SPLIT', record['fallback'])

    def test_compiler_errors_fail_the_build(self):
        _, result, record, output = self.run_tool('fail')
        self.assertEqual(result.returncode, 1)
        self.assertFalse(output.exists())
        self.assertEqual(record['mode'], 'failed')
        self.assertEqual(record['exit'], 1)
        self.assertIn('unexpected token', result.stdout)

    def test_success_without_an_executable_fails(self):
        _, result, record, output = self.run_tool('silent')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(record['mode'], 'failed')


if __name__ == '__main__':
    unittest.main()
