import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from bbc_browser_instructions import URL, audit_instruction_logging, evaluate_cohort, jsc_baseline_environment, parse_args, trial_order, run_trial, validate_document, verify_benchmark_inputs
from types import SimpleNamespace
from unittest.mock import patch
from hacker_news_browser_instructions import evaluate_pairs
from measure_sealed_github_instructions import fingerprint


def document():
    expected = dict(title='BBC Home | News', headlines=['First story', 'Second story'],
                    image_sources=['https://images.test/photo.jpg'], placeholder_sources=[])
    audit = dict(url=URL, title=expected['title'], ready='complete', viewport_width=1024,
                 viewport_height=768, fonts_status='loaded', font_faces=[], selections=[
        dict(name='body', count=1, elements=[dict(text='Full document text ' * 100)]),
        dict(name='headlines', count=2, elements=[dict(text=text) for text in expected['headlines']]),
        dict(name='images', count=1, elements=[dict(rect=dict(x=10, y=20, width=200, height=100),
            attributes=dict(src='https://images.test/photo.jpg'),
            image=dict(complete=True, natural_width=480))]),
        dict(name='all', count=2000, elements=[])])
    return audit, expected


class BBCInstructionTests(unittest.TestCase):
    def test_verified_identity_survives_a_later_shared_bundle_replacement(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'input.txt'
            source.write_text('original')
            pinned = fingerprint({source})
            with patch('bbc_browser_instructions.time.time', return_value=12345):
                verify_benchmark_inputs({source}, pinned, root)
            self.assertFalse((root / 'input-identity-failure.json').exists())
            source.write_text('later production bundle')
            receipt = json.loads((root / 'input-identity-after.json').read_text())
            self.assertEqual(receipt, dict(passed=True, observed_unix=12345, files=pinned))
            self.assertNotEqual(receipt['files'], fingerprint({source}))

    def test_transient_input_change_remains_recorded_after_original_bytes_return(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'input.txt'
            source.write_text('original')
            pinned = fingerprint({source})
            source.write_text('changed')
            changed = fingerprint({source})
            with self.assertRaisesRegex(RuntimeError, 'Pinned benchmark input changed'):
                verify_benchmark_inputs({source}, pinned, root)
            source.write_text('original')
            self.assertEqual(fingerprint({source}), pinned)
            receipt = json.loads((root / 'input-identity-failure.json').read_text())
            self.assertTrue(receipt['invalidates_cohort'])
            self.assertEqual(receipt['changed_inputs'], [dict(path=str(source),
                expected=pinned[str(source)], observed=changed[str(source)])])
            self.assertFalse((root / 'input-identity-after.json').exists())

    def test_unavailable_input_is_recorded_and_still_rejected(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'input.txt'
            source.write_text('original')
            pinned = fingerprint({source})
            source.unlink()
            with self.assertRaises(FileNotFoundError):
                verify_benchmark_inputs({source}, pinned, root)
            receipt = json.loads((root / 'input-identity-failure.json').read_text())
            self.assertTrue(receipt['invalidates_cohort'])
            self.assertEqual(receipt['unavailable_input'], str(source))
            self.assertFalse((root / 'input-identity-after.json').exists())

    def test_baseline_jit_settings_are_isolated_from_brave_and_restored_on_failure(self):
        environment = dict(VOX_PROXY='socks5h://fixture', VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY='1')
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               jsc_baseline_warmup=50, control_jsc_baseline_warmup=500)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, JSC_thresholdForJITAfterWarmUp='500',
                                            JSC_thresholdForJITSoon='100')),
                                ('vox', dict(environment, JSC_thresholdForJITAfterWarmUp='50',
                                            JSC_thresholdForJITSoon='10')),
                                ('brave', environment)])
        for engine in ['control', 'vox']:
            with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
                with self.assertRaises(RuntimeError):
                    run_trial(engine, 'same-app', engine, args)
            self.assertIs(args.vox_environment, environment)

    def test_baseline_jit_thresholds_are_explicit_and_bounded(self):
        args = ['--archive', 'fixture', '--output', 'results', '--memory-guard-registry', 'pids',
                '--capture-reference']
        defaults = parse_args(args)
        self.assertIsNone(defaults.jsc_baseline_warmup)
        self.assertIsNone(defaults.control_jsc_baseline_warmup)
        self.assertEqual(jsc_baseline_environment(None), {})
        self.assertEqual(jsc_baseline_environment(1), dict(JSC_thresholdForJITAfterWarmUp='1',
                                                         JSC_thresholdForJITSoon='1'))
        self.assertEqual(parse_args(args + ['--jsc-baseline-warmup', '50']).jsc_baseline_warmup, 50)
        controlled = parse_args(args + ['--control-vox-app', 'Vox.app', '--control-jsc-baseline-warmup', '500'])
        self.assertEqual(controlled.control_jsc_baseline_warmup, 500)
        for flag in ['--jsc-baseline-warmup', '--control-jsc-baseline-warmup']:
            for invalid in ['0', '-1', '2147483648', '1.5']:
                with self.subTest(flag=flag, invalid=invalid), self.assertRaises(SystemExit):
                    parse_args(args + ['--control-vox-app', 'Vox.app', flag, invalid])
        with self.assertRaises(SystemExit):
            parse_args(args + ['--control-jsc-baseline-warmup', '500'])

    def test_instruction_logging_accepts_phase_counters_without_verbose_font_traces(self):
        row = audit_instruction_logging({'exit': 0}, 'Vox instructions cumulative: frame_complete 123\n')
        self.assertEqual(row['exit'], 0)
        self.assertEqual(row['font_generation_diagnostic_lines'], 0)

    def test_instruction_logging_rejects_all_font_trace_kinds_and_preserves_prior_error(self):
        log = '\n'.join('Vox retained ' + kind + ' font generation: 1 -> 2'
                        for kind in ['block', 'inline', 'text'])
        row = audit_instruction_logging({'exit': 0, 'error': 'prior error'}, log)
        self.assertEqual(row['exit'], 1)
        self.assertEqual(row['font_generation_diagnostic_lines'], 3)
        self.assertIn('prior error', row['error'])
        self.assertIn('outside a diagnostic run', row['error'])

    def test_instruction_logging_retains_explicit_diagnostic_observations(self):
        row = audit_instruction_logging({'exit': 0}, 'Vox retained text font generation: 1 -> 2', True)
        self.assertEqual(row['exit'], 0)
        self.assertEqual(row['font_generation_diagnostic_lines'], 1)
        self.assertTrue(row['font_generation_diagnostics_allowed'])

    def test_instruction_logging_missing_log_invalidates_even_a_diagnostic(self):
        for diagnostic in [False, True]:
            row = audit_instruction_logging({'exit': 0}, None, diagnostic)
            self.assertEqual(row['exit'], 1)
            self.assertIsNone(row['font_generation_diagnostic_lines'])

    def test_conditional_sheet_invalidation_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_conditional_sheet_invalidation=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CONDITIONAL_SHEET_INVALIDATION='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_inactive_conditional_sheet_skip_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_inactive_conditional_sheet_skip=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INACTIVE_CONDITIONAL_SHEET_SKIP='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_classic_import_word_scan_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_classic_import_word_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CLASSIC_IMPORT_WORD_SCAN='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_longhand_shape_reuse_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_longhand_shape_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LONGHAND_SHAPE_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_longhand_eligibility_first_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_longhand_eligibility_first=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LONGHAND_ELIGIBILITY_FIRST='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_protected_value_index_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_protected_value_index=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_PROTECTED_VALUE_INDEX='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_shared_element_geometry_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_shared_element_geometry=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_SHARED_ELEMENT_GEOMETRY='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_retained_grid_layout_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_grid_layout=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_GRID_LAYOUT='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_intrinsic_seed_visits_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_intrinsic_seed_visits=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INTRINSIC_SEED_VISITS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_document_filter_memo_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_document_filter_memo=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_DOCUMENT_FILTER_MEMO='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_static_user_style_filter_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_static_user_style_filter=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_STATIC_USER_STYLE_FILTER='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_targeted_user_style_changes_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_targeted_user_style_changes=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_TARGETED_USER_STYLE_CHANGES='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_deleted_style_rule_invalidation_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_deleted_style_rule_invalidation=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_DELETED_STYLE_RULE_INVALIDATION='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_attribute_tag_buckets_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_attribute_tag_buckets=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_ATTRIBUTE_TAG_BUCKETS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_shared_node_properties_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture',
                       'VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY': '1'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_shared_node_properties=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_SHARED_NODE_PROPERTIES='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_positioned_image_ratio_reuse_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_positioned_image_ratio_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_POSITIONED_IMAGE_RATIO_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_live_pending_font_refresh_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_live_pending_font_refresh=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LIVE_PENDING_FONT_REFRESH='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_live_pending_text_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_live_pending_text_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LIVE_PENDING_TEXT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_pending_intrinsic_font_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_pending_intrinsic_font_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_intrinsic_font_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_intrinsic_font_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INTRINSIC_FONT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_constant_longhand_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_constant_longhand_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CONSTANT_LONGHAND_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_font_display_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_face_specific_font_display=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_FACE_SPECIFIC_FONT_DISPLAY='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_retained_item_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_flow_items=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_FLOW_ITEMS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_stationary_copy_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_copy_stationary_raster_commands=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_COPY_STATIONARY_RASTER_COMMANDS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_color_control_keeps_other_extensions_enabled_and_restores_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_color_longhand_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_COLOR_LONGHAND_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_extended_longhand_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_extended_longhand_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_EXTENDED_LONGHAND_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_cohort_projects_controls_and_preserves_the_integer_brave_gate(self):
        def row(count):
            return dict(exit=0, pixels_exact=True, content_exact=True,
                        capture_ownership_audit=dict(passed=True),
                        launch_instruction_interval=dict(lower=count, upper=count))
        pairs = [dict(vox=row(9 * 10**17), brave=row(10**18), control=row(11 * 10**17))
                 for _ in range(7)]
        result = evaluate_cohort(pairs, True)
        self.assertTrue(result['passed'])
        self.assertTrue(result['matched_control']['passed'])
        self.assertEqual(result['pairs'], 7)
        pairs[0]['vox'] = row(9 * 10**17 + 1)
        self.assertFalse(evaluate_cohort(pairs, True)['passed'])
        plain = [dict(vox=pair['vox'], brave=pair['brave']) for pair in pairs]
        self.assertEqual(evaluate_cohort(plain)['passed'], False)
        for invalid in [pairs[:6], plain, [dict(pair, extra=row(1)) for pair in pairs]]:
            with self.assertRaises(RuntimeError):
                evaluate_cohort(invalid, True)
        for key, value in [('exit', 1), ('pixels_exact', False), ('content_exact', False),
                           ('launch_instruction_interval', dict(lower=0, upper=1))]:
            with self.subTest(key=key):
                broken = [dict(pair) for pair in pairs]
                broken[0]['control'] = dict(row(11 * 10**17), **{key: value})
                with self.assertRaises(RuntimeError):
                    evaluate_cohort(broken, True)

    def test_cohort_rejects_missing_or_failed_capture_ownership_even_with_lower_counts(self):
        def row(count):
            return dict(exit=0, pixels_exact=True, content_exact=True,
                        capture_ownership_audit=dict(passed=True),
                        launch_instruction_interval=dict(lower=count, upper=count))
        for engine in ['vox', 'control']:
            for audit in [None, {}, dict(passed=False)]:
                pairs = [dict(vox=row(100), brave=row(1000), control=row(200)) for _ in range(7)]
                if audit is None:
                    del pairs[0][engine]['capture_ownership_audit']
                else:
                    pairs[0][engine]['capture_ownership_audit'] = audit
                with self.subTest(engine=engine, audit=audit), self.assertRaisesRegex(
                        RuntimeError, 'endpoint-matched live coalition ownership'):
                    evaluate_cohort(pairs, True)

    def test_attribute_and_scope_controls_never_leak_between_trials(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        for attributes, scopes in [(True, False), (False, True), (True, True)]:
            args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                control_disable_attribute_case_buckets=attributes, control_disable_persistent_scope_jumps=scopes)
            expected = dict(environment)
            if attributes:
                expected['VOX_DISABLE_ATTRIBUTE_CASE_BUCKETS'] = '1'
            if scopes:
                expected['VOX_DISABLE_PERSISTENT_SCOPE_JUMPS'] = '1'
            seen = []
            def observe(engine, app, folder, options):
                seen.append((engine, dict(options.vox_environment)))
                return {'exit': 0}
            with self.subTest(attributes=attributes, scopes=scopes):
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
                    for engine in ['control', 'vox', 'brave']:
                        run_trial(engine, 'same-app', engine, args)
                self.assertEqual(seen, [('vox', expected), ('vox', environment), ('brave', environment)])
                self.assertIs(args.vox_environment, environment)
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
                    with self.assertRaises(RuntimeError):
                        run_trial('control', 'same-app', 'control', args)
                self.assertIs(args.vox_environment, environment)

    def test_geometry_and_allocator_controls_are_isolated_and_restored(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        for geometry, allocator in [(True, False), (False, True), (True, True)]:
            args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                control_disable_client_geometry_index=geometry,
                control_disable_tracked_persistent_shortcut=allocator)
            expected = dict(environment)
            if geometry:
                expected['VOX_DISABLE_VISUAL_CONTEXT_INDEX'] = '1'
            if allocator:
                expected['VOX_DISABLE_TRACKED_PERSISTENT_SHORTCUT'] = '1'
            seen = []
            def observe(engine, app, folder, options):
                seen.append((engine, dict(options.vox_environment)))
                return {'exit': 0}
            with self.subTest(geometry=geometry, allocator=allocator):
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
                    for engine in ['control', 'vox', 'brave']:
                        run_trial(engine, 'same-app', engine, args)
                self.assertEqual(seen, [('vox', expected), ('vox', environment), ('brave', environment)])
                self.assertIs(args.vox_environment, environment)
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
                    with self.assertRaises(RuntimeError):
                        run_trial('control', 'same-app', 'control', args)
                self.assertIs(args.vox_environment, environment)

    def test_historical_webp_policy_is_explicit_and_does_not_require_a_control_app(self):
        args = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference']
        self.assertFalse(parse_args(args).retain_incremental_webp_paint_policy)
        self.assertTrue(parse_args(args + ['--retain-incremental-webp-paint-policy']).retain_incremental_webp_paint_policy)

    def test_optimization_controls_require_a_control_app(self):
        args = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference']
        for flag in ['--control-retain-flow-style-identities', '--control-disable-retained-simple-svg', '--control-retain-definite-intrinsic-measurement', '--control-retain-selector-substring-scan', '--control-retain-redundant-sheet-removal', '--control-retain-full-font-input-scan', '--control-disable-early-text-font-requests', '--control-retain-selector-rule-font-sync', '--control-retain-empty-procedural-styles', '--control-copy-stationary-raster-pixels', '--control-disable-inline-measurement-reuse',
                     '--control-disable-grid-width-only', '--control-disable-stationary-raster',
                     '--control-disable-client-geometry-index',
                     '--control-disable-tracked-persistent-shortcut',
                     '--control-disable-attribute-case-buckets', '--control-disable-persistent-scope-jumps',
                     '--control-disable-extended-longhand-reuse', '--control-disable-color-longhand-reuse',
                     '--control-copy-stationary-raster-commands', '--control-disable-retained-flow-items',
                     '--control-disable-face-specific-font-display', '--control-disable-constant-longhand-reuse',
                     '--control-disable-intrinsic-font-reuse', '--control-disable-pending-intrinsic-font-reuse', '--control-disable-live-pending-text-reuse', '--control-disable-live-pending-font-refresh', '--control-disable-positioned-image-ratio-reuse', '--control-disable-conditional-sheet-invalidation', '--control-disable-inactive-conditional-sheet-skip', '--control-disable-classic-import-word-scan', '--control-disable-longhand-shape-reuse', '--control-disable-longhand-eligibility-first', '--control-disable-protected-value-index', '--control-disable-shared-element-geometry', '--control-disable-shared-node-properties', '--control-disable-attribute-tag-buckets', '--control-disable-deleted-style-rule-invalidation', '--control-disable-targeted-user-style-changes', '--control-disable-static-user-style-filter', '--control-disable-document-filter-memo', '--control-disable-retained-grid-layout', '--control-disable-intrinsic-seed-visits']:
            with self.subTest(flag=flag):
                with self.assertRaises(SystemExit):
                    parse_args(args + [flag])
                self.assertTrue(getattr(parse_args(args + [flag, '--control-vox-app', 'Vox.app']),
                                        flag[2:].replace('-', '_')))

    def test_stationary_control_flag_never_reaches_candidate_or_brave(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_stationary_raster=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_STATIONARY_RASTER_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)

    def test_absolute_length_context_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_absolute_length_context=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_ABSOLUTE_LENGTH_CONTEXT='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_image_attribute_source_parse_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_image_attribute_source_parse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_IMAGE_ATTRIBUTE_SOURCE_PARSE='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_flow_style_identities_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_flow_style_identities=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_FLOW_STYLE_IDENTITIES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_ancestor_rehash_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_ancestor_rehash=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_ANCESTOR_REHASH='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_formatting_tree_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_formatting_trees=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_FORMATTING_TREES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_property_edge_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_property_edge_resolution=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_PROPERTY_EDGE_RESOLUTION='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_definite_intrinsic_measurement_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_definite_intrinsic_measurement=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_DEFINITE_INTRINSIC_MEASUREMENT='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_simple_svg_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_simple_svg=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_SIMPLE_SVG='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_selector_substring_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_selector_substring_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_SELECTOR_SUBSTRING_SCAN='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_redundant_sheet_removal_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_redundant_sheet_removal=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_REDUNDANT_SHEET_REMOVAL='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_full_font_input_scan_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_full_font_input_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_FULL_FONT_INPUT_SCAN='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_early_text_font_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_early_text_font_requests=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_EARLY_TEXT_FONT_REQUESTS='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_selector_rule_font_sync_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_selector_rule_font_sync=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_SELECTOR_RULE_FONT_SYNC='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_empty_procedural_style_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_empty_procedural_styles=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_EMPTY_PROCEDURAL_STYLES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_stationary_snapshot_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_copy_stationary_raster_pixels=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_COPY_STATIONARY_RASTER_PIXELS='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_inline_measurement_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_inline_measurement_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INLINE_MEASUREMENT_REUSE='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_same_binary_control_disables_only_its_grid_width_optimization(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            run_trial('control', 'same-app', 'control', args)
            run_trial('vox', 'same-app', 'candidate', args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_GRID_WIDTH_ONLY='1')),
                                ('vox', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_matched_controls_alternate_with_candidate_and_brave(self):
        self.assertEqual(trial_order(0), ['vox', 'brave'])
        self.assertEqual(trial_order(1), ['brave', 'vox'])
        self.assertEqual(trial_order(0, True), ['control', 'vox', 'brave'])
        self.assertEqual(trial_order(1, True), ['brave', 'vox', 'control'])
        self.assertEqual(trial_order(2, True), ['control', 'vox', 'brave'])

    def test_full_source_content_and_visible_images_are_required(self):
        audit, expected = document()
        result = validate_document(audit, expected)
        self.assertTrue(result['passed'])
        self.assertEqual(result['headlines'], 2)
        self.assertEqual(result['visible_decoded_images'], 1)

    def test_wrong_document_or_unsettled_state_is_rejected(self):
        for key, value in [('url', URL + 'news'), ('title', 'BBC unavailable'),
                           ('ready', 'interactive'), ('viewport_height', 767),
                           ('fonts_status', 'loading')]:
            audit, expected = document()
            audit[key] = value
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_truncated_missing_and_reordered_headlines_are_rejected(self):
        for mutation in ('truncate', 'reorder', 'replace', 'count', 'missing'):
            audit, expected = document()
            row = audit['selections'][1]
            if mutation == 'truncate':
                row['elements'].pop()
            elif mutation == 'reorder':
                row['elements'].reverse()
            elif mutation == 'replace':
                row['elements'][0]['text'] = 'Different news'
            elif mutation == 'count':
                row['count'] += 1
            else:
                audit['selections'].pop(1)
            with self.subTest(mutation=mutation), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_missing_images_or_visible_decode_failures_reject_credit(self):
        for mutation in ('missing', 'incomplete', 'zero', 'hidden'):
            audit, expected = document()
            row = audit['selections'][2]
            if mutation == 'missing':
                row['elements'].clear()
            elif mutation == 'incomplete':
                row['elements'][0]['image']['complete'] = False
            elif mutation == 'zero':
                row['elements'][0]['image']['natural_width'] = 0
            else:
                row['elements'][0]['rect']['y'] = 800
            with self.subTest(mutation=mutation), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_retained_native_decode_and_offscreen_lazy_images(self):
        audit, expected = document()
        audit['selections'][2]['elements'][0]['image'] = dict(paint_decoded=True, paint_width=480)
        validate_document(audit, expected)
        expected['image_sources'].append('https://images.test/second.jpg')
        expected['image_sources'].sort()
        row = audit['selections'][2]
        row['count'] += 1
        row['elements'].append(dict(rect=dict(x=0, y=900, width=480, height=240), image={},
                                   attributes=dict(src='https://images.test/second.jpg')))
        validate_document(audit, expected)

    def test_hydration_can_remove_only_source_loading_placeholders(self):
        audit, expected = document()
        expected['placeholder_sources'] = ['https://assets.test/grey-placeholder.png']
        validate_document(audit, expected)
        images = audit['selections'][2]
        images['count'] += 1
        images['elements'].append(dict(rect=dict(x=0, y=900, width=200, height=100), image={},
            attributes=dict(src=expected['placeholder_sources'][0])))
        validate_document(audit, expected)
        images['elements'][-1]['attributes']['src'] = 'https://images.test/unexpected.jpg'
        with self.assertRaises(RuntimeError):
            validate_document(audit, expected)

    def test_requested_font_errors_and_missing_parsed_font_reject_credit(self):
        for face in [dict(status='error'), dict(status='loading'),
                     dict(status='loaded', parsed_font_present=False)]:
            audit, expected = document()
            audit['font_faces'] = [face]
            with self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_only_proven_local_font_absence_may_use_platform_fallback(self):
        audit, expected = document()
        expected['local_font_fallback_sources'] = {'bbc-fallback': ['Arial', 'Arial Bold']}
        face = dict(family='BBC-Fallback', status='error', declared_sources=['Arial'])
        audit['font_faces'] = [face]
        result = validate_document(audit, expected)
        self.assertEqual(result['unavailable_local_fallbacks'], [dict(family='BBC-Fallback', sources=['Arial'])])
        for sources in [[], ['Arial', 'https://fonts.test/missing.woff2'], ['Unknown font']]:
            face['declared_sources'] = sources
            with self.subTest(sources=sources), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_acceptance_requires_seven_pairs_and_existing_references(self):
        args = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json']
        for extra in [[], ['--expected-vox', 'v.png', '--expected-brave', 'b.png', '--repeat', '6']]:
            with self.assertRaises(SystemExit):
                parse_args(args + extra)
        parsed = parse_args(args + ['--expected-vox', 'v.png', '--expected-brave', 'b.png'])
        self.assertEqual(parsed.repeat, 7)
        self.assertEqual(parsed.scale, 2)
        self.assertFalse(parsed.capture_reference)
        self.assertTrue(parse_args(args + ['--capture-reference']).capture_reference)
        self.assertEqual(parse_args(args + ['--capture-reference', '--reference-engine', 'brave'])
                         .reference_engine, 'brave')
        with self.assertRaises(SystemExit):
            parse_args(args + ['--expected-vox', 'v.png', '--expected-brave', 'b.png',
                               '--reference-engine', 'brave'])

    def test_reference_capture_cannot_pass_acceptance(self):
        pairs = [dict(vox=dict(exit=0, content_exact=True, reference_capture=True),
                      brave=dict(exit=0, content_exact=True, reference_capture=True))] * 7
        with self.assertRaises(RuntimeError):
            evaluate_pairs(pairs, .9, 'launch')


if __name__ == '__main__':
    unittest.main()
