import unittest

from bbc_browser_instructions import URL, evaluate_cohort, parse_args, trial_order, run_trial, validate_document
from types import SimpleNamespace
from unittest.mock import patch
from hacker_news_browser_instructions import evaluate_pairs


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

    def test_optimization_controls_require_a_control_app(self):
        args = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference']
        for flag in ['--control-disable-grid-width-only', '--control-disable-stationary-raster',
                     '--control-disable-client-geometry-index',
                     '--control-disable-tracked-persistent-shortcut',
                     '--control-disable-attribute-case-buckets', '--control-disable-persistent-scope-jumps',
                     '--control-disable-extended-longhand-reuse', '--control-disable-color-longhand-reuse',
                     '--control-copy-stationary-raster-commands', '--control-disable-retained-flow-items',
                     '--control-disable-face-specific-font-display', '--control-disable-constant-longhand-reuse',
                     '--control-disable-intrinsic-font-reuse', '--control-disable-pending-intrinsic-font-reuse', '--control-disable-live-pending-text-reuse']:
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
