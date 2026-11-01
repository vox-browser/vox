import copy
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import cnn_home_browser_instructions as benchmark


class CNNHomeInstructionTests(unittest.TestCase):
    def test_controls_alternate_with_the_candidate_and_brave(self):
        self.assertEqual(benchmark.trial_order(0), ['vox', 'brave'])
        self.assertEqual(benchmark.trial_order(1), ['brave', 'vox'])
        self.assertEqual(benchmark.trial_order(0, True), ['control', 'vox', 'brave'])
        self.assertEqual(benchmark.trial_order(1, True), ['brave', 'vox', 'control'])

    def test_separate_control_app_does_not_disable_any_engine_optimization(self):
        names = ['control_geometry_snapshot_keys', 'control_live_font_cascades', 'control_hidden_animations', 'control_font_completion',
                 'control_lazy_images', 'control_static_media']
        args = SimpleNamespace(control_vox_app=None, **dict.fromkeys(names, False))
        self.assertEqual(benchmark.control_environment(args), {})
        args.control_vox_app = Path('separately-pinned-control.app')
        self.assertEqual(benchmark.control_environment(args), {})
        args.control_vox_app = None
        args.control_hidden_animations = True
        self.assertEqual(benchmark.control_environment(args), {'VOX_DISABLE_HIDDEN_ANIMATION_THROTTLING': '1'})

    def expected(self):
        return dict(title='Latest | CNN', headlines=['first', 'second'], image_sources=['photo.jpg'])

    def audit(self):
        return dict(url=benchmark.URL, title='Latest | CNN', ready='complete',
            viewport_width=1024, viewport_height=768, fonts_status='loaded',
            font_faces=[dict(family='cnn_sans_display', weight=w, status='loaded',
                parsed_font_present=True, source_path='decoded.ttf') for w in ('auto', '500', '700')],
            selections=[dict(name='body', count=1, elements=[dict(text='story ' * 1000)]),
                dict(name='headlines', count=2, elements=[dict(text='first'), dict(text='second')]),
                dict(name='images', count=1, elements=[dict(attributes={'src': 'photo.jpg'},
                    rect=dict(x=20, y=120, width=269, height=151),
                    image=dict(complete=True, natural_width=960))]),
                dict(name='all', count=3661, elements=[])])

    def test_requires_every_headline_in_source_order_and_all_image_sources(self):
        self.assertTrue(benchmark.validate_document(self.audit(), self.expected())['passed'])
        for mutate in (
            lambda a: a['selections'][1]['elements'].reverse(),
            lambda a: a['selections'][1]['elements'].pop(),
            lambda a: a['selections'][2]['elements'][0]['attributes'].update(src='other.jpg'),
            lambda a: a.update(url='https://example.com/'),
            lambda a: a.update(ready='loading'),
            lambda a: a.update(viewport_height=740),
            lambda a: a['selections'][0]['elements'][0].update(text='error page'),
            lambda a: a['selections'][3].update(count=10),
            lambda a: a['font_faces'][0].update(status='unloaded'),
            lambda a: a['selections'][2]['elements'][0]['image'].update(complete=False),
        ):
            audit = self.audit()
            mutate(audit)
            with self.subTest(audit=audit), self.assertRaises(RuntimeError):
                benchmark.validate_document(audit, self.expected())

    def test_only_visible_images_require_decoding_and_retained_paint_is_accepted(self):
        audit, expected = self.audit(), self.expected()
        image = audit['selections'][2]['elements'][0]
        image['image'] = dict(complete=False, paint_decoded=True, paint_width=960)
        offscreen = copy.deepcopy(image)
        offscreen['rect']['y'] = 1200
        offscreen['image'] = dict(complete=False)
        audit['selections'][2]['elements'].append(offscreen)
        audit['selections'][2]['count'] += 1
        expected['image_sources'].append('photo.jpg')
        self.assertEqual(benchmark.validate_document(audit, expected)['visible_images'], 1)

    def pairs(self, count=7, vox=900, brave=1000):
        return [dict(vox=dict(exit=0, content_exact=True, pixels_exact=True,
                             filter_gate=dict(passed=True),
                             launch_instruction_interval=dict(lower=vox, upper=vox)),
                     brave=dict(exit=0, content_exact=True, pixels_exact=True,
                               brave_setup=dict(selected=['pinned lists']),
                               launch_instruction_interval=dict(lower=brave, upper=brave + 1)))
                for _ in range(count)]

    def test_diagnostic_never_grants_acceptance_and_acceptance_needs_seven_pairs(self):
        self.assertFalse(benchmark.summarize(self.pairs(1), diagnostic=True)['acceptance'])
        with self.assertRaises(RuntimeError):
            benchmark.summarize(self.pairs(6))
        self.assertTrue(benchmark.summarize(self.pairs())['acceptance'])
        self.assertFalse(benchmark.summarize(self.pairs(vox=901))['acceptance'])
        self.assertFalse(benchmark.summarize(self.pairs(vox=9 * 10**17 + 1,
                                                     brave=10**18))['acceptance'])
        for key in ('pixels_exact', 'content_exact'):
            pairs = self.pairs()
            pairs[0]['vox'][key] = False
            with self.assertRaises(RuntimeError):
                benchmark.summarize(pairs)
        pairs = self.pairs()
        pairs[0]['vox']['filter_gate']['passed'] = False
        with self.assertRaisesRegex(RuntimeError, 'full-uBO'):
            benchmark.summarize(pairs)

    def test_control_statistics_require_complete_verified_controls(self):
        pairs = self.pairs()
        for pair in pairs:
            pair['control'] = copy.deepcopy(pair['vox'])
            pair['control']['launch_instruction_interval'] = dict(lower=950, upper=950)
        summary = benchmark.summarize(pairs)
        self.assertTrue(summary['acceptance'])
        self.assertTrue(summary['matched_control']['passed'])
        pairs[0]['control']['pixels_exact'] = False
        with self.assertRaises(RuntimeError):
            benchmark.summarize(pairs)

    def test_cli_rejects_short_acceptance_and_retains_explicit_diagnostics(self):
        arguments = [item for name in ('output', 'memory-guard-registry', 'brave-profile-template',
                     'vox-cache-template', 'extension', 'checker', 'expected', 'diff-tool')
                     for item in ('--' + name, 'private-' + name)]
        args = benchmark.parse_args(arguments)
        self.assertEqual(args.repeat, 7)
        self.assertEqual(args.settle_seconds, 5)
        with self.assertRaises(SystemExit):
            benchmark.parse_args(arguments + ['--repeat', '1'])
        self.assertTrue(benchmark.parse_args(arguments + ['--diagnostic', '--repeat', '1']).diagnostic)
        self.assertTrue(benchmark.parse_args(arguments + ['--control-font-completion']).control_font_completion)
        self.assertTrue(benchmark.parse_args(arguments + ['--control-hidden-animations']).control_hidden_animations)
        self.assertTrue(benchmark.parse_args(arguments + ['--control-live-font-cascades']).control_live_font_cascades)
        args = benchmark.parse_args(arguments + ['--control-geometry-snapshot-keys'])
        self.assertEqual(benchmark.control_environment(args), {'VOX_DISABLE_GEOMETRY_SNAPSHOT_KEYS': '1'})
        with self.assertRaises(SystemExit):
            benchmark.parse_args(arguments + ['--control-font-completion', '--control-lazy-images'])

    def test_full_extension_bootstrap_precedes_settings_and_rejects_changed_filters(self):
        connection, background = Mock(), Mock()
        connection.call.return_value = dict(targetInfos=[dict(type='background_page',
            url='chrome-extension://id/background.html', targetId='extension')])
        selected = [r['name'] for r in benchmark.json.loads(
            (benchmark.REPO / 'adblock/lists/manifest.json').read_text())['lists']]
        settings = dict(selected=selected, autoUpdate=False, userFilters='')
        for changes in ({}, dict(selected=[]), dict(autoUpdate=True), dict(userFilters='hide CNN')):
            background.call.side_effect = [dict(result=dict(value=True)), dict(result=dict(value=True)),
                                           dict(result=dict(value=dict(settings, **changes)))]
            with patch.object(benchmark.browser, 'CDP', return_value=background):
                if changes:
                    with self.assertRaises(RuntimeError):
                        benchmark.full_ubo_ready(connection, 1234, benchmark.time.monotonic() + 2)
                else:
                    self.assertEqual(benchmark.full_ubo_ready(connection, 1234,
                        benchmark.time.monotonic() + 2), settings)
            self.assertTrue(background.sock.close.called)


if __name__ == '__main__':
    unittest.main()
