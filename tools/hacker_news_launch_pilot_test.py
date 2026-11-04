from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import tempfile
import unittest

import hacker_news_launch_pilot as pilot
from hn_launch_cost import aggregate
from hn_launch_cost.sampler import sample_statistics


def observation(trial, name, instructions):
    return dict(trial=trial, variant=name, instructions=instructions, exit=0,
                pixels_exact=True, content_exact=True, inputs_unchanged=True)


class LaunchPilotTests(unittest.TestCase):
    def test_rotation_keeps_every_variant_in_every_round(self):
        variants = ['a', 'b', 'c']
        self.assertEqual([pilot.rotated_variants(variants, i) for i in range(1, 5)],
                         [['a', 'b', 'c'], ['b', 'c', 'a'], ['c', 'a', 'b'], ['a', 'b', 'c']])

    def test_failed_attempts_are_retained_and_invalidate_statistics(self):
        variants = [dict(name='base'), dict(name='candidate')]
        rows = [observation(i, name, 100 if name == 'base' else 80)
                for i in range(1, 4) for name in ['base', 'candidate']]
        rows[-1].update(exit=1, error='ownership failed')
        result = pilot.summarize(rows, variants, 3)
        self.assertEqual(result['candidate']['counts'], [80, 80, 80])
        self.assertFalse(result['candidate']['all_gates'])
        self.assertIsNone(result['candidate']['median'])
        self.assertEqual(result['candidate']['paired_saving_vs_base'], dict(values=[], median=None))

    def test_complete_pilot_keeps_exact_counts_and_negative_savings(self):
        rows = [observation(1, 'base', 101), observation(1, 'candidate', 90),
                observation(2, 'candidate', 120), observation(2, 'base', 100)]
        result = pilot.summarize(rows, [dict(name='base'), dict(name='candidate')], 2)
        self.assertEqual(result['base']['median'], 100.5)
        self.assertEqual(result['candidate']['paired_saving_vs_base'], dict(values=[11, -20], median=-4.5))

    def test_incomplete_duplicate_or_unverified_trials_cannot_pass(self):
        original = [observation(1, 'base', 100), observation(2, 'base', 99)]
        for rows in [original[:1], [original[0], original[0]],
                     [original[0], dict(original[1], inputs_unchanged=False)],
                     [original[0], dict(original[1], pixels_exact=False)],
                     [original[0], dict(original[1], content_exact=False)],
                     [original[0], dict(original[1], instructions=None)]]:
            with self.subTest(rows=rows):
                result = pilot.summarize(rows, [dict(name='base')], 2)['base']
                self.assertFalse(result['all_gates'])
                self.assertIsNone(result['median'])

    def test_input_replacement_before_launch_prevents_browser_start(self):
        args = SimpleNamespace(output=Path('/unused'))
        variant = dict(name='base', app='/unused', environment={})
        with patch.object(pilot.hn, 'fingerprint', return_value={'new': 'hash'}), \
                patch.object(pilot.hn, 'run_browser') as run:
            row = pilot.checked_trial(args, variant, 1, set(), {'old': 'hash'})
        run.assert_not_called()
        self.assertEqual(row['exit'], 1)
        self.assertIn('before the trial', row['error'])

    def test_runtime_changes_after_capture_keep_the_attempt_but_reject_it(self):
        with tempfile.TemporaryDirectory() as temp:
            args = SimpleNamespace(output=Path(temp))
            variant = dict(name='base', app=temp, environment={})
            result = dict(exit=0, kernel_exit_status=0, pixels_exact=True, content_exact=True,
                          launch_instruction_interval=dict(lower=123, upper=123))
            with patch.object(pilot.hn, 'fingerprint', side_effect=[{'old': 'hash'}, {'new': 'hash'}]), \
                    patch.object(pilot.hn, 'run_browser', return_value=result):
                row = pilot.checked_trial(args, variant, 1, set(), {'old': 'hash'})
            self.assertEqual(row['instructions'], 123)
            self.assertEqual(row['exit'], 1)
            self.assertIn('during the trial', row['error'])
            self.assertNotIn('inputs_unchanged', row)

    def test_missing_or_inexact_counter_invalidates_successful_capture(self):
        with tempfile.TemporaryDirectory() as temp:
            args = SimpleNamespace(output=Path(temp))
            variant = dict(name='base', app=temp, environment={})
            for interval in [{}, dict(lower=123, upper=124), dict(lower=True, upper=True)]:
                result = dict(exit=0, kernel_exit_status=0, pixels_exact=True, content_exact=True,
                              launch_instruction_interval=interval)
                with patch.object(pilot.hn, 'fingerprint', return_value={}), \
                        patch.object(pilot.hn, 'run_browser', return_value=result):
                    row = pilot.checked_trial(args, variant, 1, set(), {})
                self.assertEqual(row['exit'], 1)
                self.assertIn('counter', row['error'])

    def test_bundle_helpers_resources_runtime_and_probe_are_pinned(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = root / 'archive'
            archive.mkdir()
            (archive / 'body').write_text('fixture')
            app = root / 'Vox.app'
            (app / 'Contents/MacOS').mkdir(parents=True)
            (app / 'Contents/Resources').mkdir()
            helper = app / 'Contents/MacOS/VoxAdblockWorker'
            resource = app / 'Contents/Resources/engine.bin'
            helper.touch()
            resource.touch()
            library, runtime, probe = [root / name for name in ['native.dylib', 'ua.css', 'probe.dylib']]
            for path in [library, runtime, probe]:
                path.touch()
            args = SimpleNamespace(expected=root / 'ref.png', diff_tool=root / 'diff',
                                   audit_config=root / 'audit', home_archive=archive)
            variant = dict(name='base', app=str(app), environment=dict(DYLD_INSERT_LIBRARIES=str(probe)))
            def dependencies(binary):
                return {probe} if binary == probe else {library}
            with patch.object(pilot.hn, 'native_dependencies', side_effect=dependencies), \
                    patch.object(pilot.hn, 'runtime_input_paths', return_value=[runtime]):
                paths = pilot.input_paths(args, [variant])
            self.assertTrue({helper, resource, library, runtime, probe, archive / 'body'} <= paths)


class SampleAggregationTests(unittest.TestCase):
    def test_successful_sample_command_with_empty_call_graph_has_no_coverage(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            (folder / 'sample-worker.txt').write_text('Header\nCall graph:\n\nTotal number in stack\n')
            (folder / 'sample-vox.txt').write_text('Header\nCall graph:\n    4 Main Thread\n    + 4 render (in Vox)\nTotal number in stack\n')
            records = sample_statistics(folder)
        self.assertEqual(records['worker'], dict(threads=0, busy_samples=0))
        self.assertEqual(records['vox'], dict(threads=1, busy_samples=4))

    def test_waiting_samples_and_recursive_calls_do_not_inflate_busy_counts(self):
        tree = ['Main Thread', 10, [
            ['render [Vox]', 6, [['render [Vox]', 4, []]]],
            ['mach_msg2_trap [libsystem_kernel.dylib]', 4, []]]]
        inclusive, self_counts = aggregate.collections.Counter(), aggregate.collections.Counter()
        self.assertEqual(aggregate.busy(tree), 6)
        self.assertEqual(aggregate.busy(tree), 6)
        for child in tree[2]:
            aggregate.walk(child, frozenset(), inclusive, self_counts, None, False)
        self.assertEqual(inclusive['render [Vox]'], 6)
        self.assertEqual(self_counts['render [Vox]'], 6)
        self.assertNotIn('mach_msg2_trap [libsystem_kernel.dylib]', inclusive)

    def test_sample_parser_retains_thread_and_image_identity(self):
        sample = '''Header
Call graph:
    10 Thread_123: Main Thread
    + 6 render (in Vox) + 12 [0x123abc]
    + ! 4 work (in libLadybirdVSkiaText.dylib) + 5 [0xdef]
    + 4 mach_msg2_trap (in libsystem_kernel.dylib) + 8 [0x456]
Total number in stack
Ignored footer
'''
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'sample.txt'
            path.write_text(sample)
            trees = aggregate.parse(path)
        self.assertEqual(len(trees), 1)
        self.assertEqual(aggregate.busy(trees[0]), 6)
        self.assertEqual(trees[0][2][0][0], 'render [Vox]')
        self.assertEqual(trees[0][2][0][2][0][0], 'work [libLadybirdVSkiaText.dylib]')


if __name__ == '__main__':
    unittest.main()
