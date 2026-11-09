import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import ci_stackoverflow_instructions as ci


class DependencySelectionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.repo = self.root / 'project'
        runner = self.repo / ci.SCRIPT
        runner.parent.mkdir(parents=True)
        runner.write_text('# test runner fixture\n')
        self.environment = {
            'VOX_CI_EVIDENCE': 'Build/ci-stackoverflow-1-1',
            'VOX_CI_BASELINE_SHA': 'c' * 40,
            'VOX_CI_CANDIDATE_SHA': '',
            'RUNNER_TEMP': str(self.root / 'runner-temp'),
        }

    def test_fetches_latest_ui2_outside_build_and_records_actual_revision(self):
        def revision(command, cwd):
            return 'b' * 40 if cwd.name.startswith('vox-ui2-') else 'a' * 40

        class ReadyToCompile(Exception):
            pass

        def command(name, *args, **kwargs):
            if name == 'build-v':
                raise ReadyToCompile

        with patch.dict(os.environ, self.environment), patch.object(ci, 'ROOT', self.repo), \
                patch.object(ci, 'PINS', {'v': ('vlang/v', 'a' * 40)}), \
                patch.object(ci.Run, 'select'), patch.object(ci, 'read', side_effect=revision), \
                patch.object(ci.Run, 'command', side_effect=command) as commands:
            run = ci.Run()
            with self.assertRaises(ReadyToCompile):
                run.build()
        calls = {call.args[0]: call for call in commands.call_args_list}
        ui2 = calls['ui2-fetch']
        self.assertEqual(ui2.args[1], ['git', 'fetch', '--depth', '1', 'origin', 'HEAD'])
        self.assertTrue(ui2.kwargs['cwd'].is_relative_to(self.root / 'runner-temp'))
        self.assertFalse(ui2.kwargs['cwd'].is_relative_to(self.repo / 'Build'))
        self.assertEqual(calls['v-fetch'].args[1][-1], 'a' * 40)
        self.assertEqual(calls['build-v'].kwargs['env']['UI2_SOURCE_DIR'], str(ui2.kwargs['cwd']))
        state = json.loads((run.output / 'state.json').read_text())
        self.assertEqual(state['dependencies']['ui2'], ['vlang/ui2', 'b' * 40])

    def test_still_rejects_a_mismatched_fixed_compiler_revision(self):
        with patch.dict(os.environ, self.environment), patch.object(ci, 'ROOT', self.repo), \
                patch.object(ci, 'PINS', {'v': ('vlang/v', 'a' * 40)}), \
                patch.object(ci.Run, 'select'), patch.object(ci.Run, 'command'), \
                patch.object(ci, 'read', return_value='d' * 40):
            with self.assertRaisesRegex(RuntimeError, 'Dependency pin mismatch'):
                ci.Run().build()


if __name__ == '__main__':
    unittest.main()
