#!/usr/bin/env python3
"""Focused pure Python checks; does not launch browsers or read CPU counters."""
import hashlib
import html
import inspect
import json
import os
from pathlib import Path
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from coalition_instruction_counts import CoalitionReading
import measure_sealed_github_instructions as measurement


class SyntheticFixture:
    """The gate's fixed source shape, without any ignored cache dependency."""
    about = 'A small compiler & language — fixture'

    def __init__(self):
        self.links = [('/vlang/v/' + kind + '/main/file' + str(index), 'file' + str(index))
                      for index in range(32) for kind in ['tree', 'blob']]
        rows = ['<tr class="react-directory-row">' + ''.join(
            '<td><a href="' + href + '">' + text + '</a></td>'
            for href, text in self.links[index:index + 2]) + '</tr>'
            for index in range(0, 64, 2)]
        images = ['https://avatars.githubusercontent.com/u/46413578?s=60&v=4',
                  'https://raw.githubusercontent.com/vlang/v-logo/master/dist/v-logo.svg?sanitize=true']
        images += ['https://missing.test/image' + str(index) for index in range(11)]
        self.body = ('<!doctype html><html><body><table>' + ''.join(rows) + '</table>'
                     '<div class="HideWhenNarrow__fixture"><p class="description__fixture">'
                     + html.escape(self.about) + '</p></div>' + ''.join(
                         '<img src="' + html.escape(url, quote=True) + '">' for url in images)
                     + '</body></html>').encode()

    def lookup_response(self, url, resource_type):
        if (url, resource_type) == (measurement.URL, 'Document'):
            return self.body, 'text/html', None
        return None


class ContentGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = SyntheticFixture()
        cls.expected = measurement.source_expectations(cls.fixture)

    def audit(self):
        body = self.fixture.lookup_response(measurement.URL, 'Document')[0]
        parser = measurement.FixtureHTML()
        parser.feed(body.decode())
        is_row = lambda node: node['tag'] == 'tr' and 'react-directory-row' in node['attrs'].get('class', '').split()
        links = [dict(text=measurement.text_content(node), attributes=dict(node['attrs']),
                      rect=dict(x=10, y=180, width=80, height=20)) for node in parser.nodes
                 if node['tag'] == 'a' and measurement.re.search(r'/vlang/v/(?:tree|blob)/', node['attrs'].get('href', ''))
                 and measurement.ancestor(node, is_row)]
        about = next(node for node in parser.nodes if node['tag'] == 'p'
                     and 'description__' in node['attrs'].get('class', '')
                     and measurement.ancestor(node, lambda p: 'HideWhenNarrow__' in p['attrs'].get('class', '')))
        images = []
        for node in parser.nodes:
            if node['tag'] != 'img':
                continue
            width, height = self.expected['decoded_images'].get(node['attrs']['src'], [0, 0])
            images.append(dict(text='', attributes=dict(node['attrs']), image=dict(
                complete=True, natural_width=width, natural_height=height)))
        return dict(url=measurement.URL, ready='complete', viewport_width=1024, viewport_height=768,
                    selections=[dict(name='rows', count=32, elements=[dict(rect=dict(x=10, y=180, width=700, height=30))]),
                                dict(name='fileLinks', count=64, elements=links),
                                dict(name='about', count=1, elements=[dict(text=measurement.text_content(about), rect=dict(x=700, y=200, width=250, height=40))]),
                                dict(name='images', count=13, elements=images)])

    def test_independent_fixture_expectations(self):
        self.assertEqual(self.expected['document_sha256'], hashlib.sha256(self.fixture.body).hexdigest())
        self.assertEqual(self.expected['about_text_sha256'], hashlib.sha256(self.fixture.about.encode()).hexdigest())
        links = sorted(('https://github.com' + href, text) for href, text in self.fixture.links)
        self.assertEqual(self.expected['file_links_sha256'], hashlib.sha256(
            json.dumps(links, separators=(',', ':'), ensure_ascii=False).encode()).hexdigest())
        self.assertEqual((self.expected['rows'], self.expected['file_links']), (32, 64))

    def test_explicit_javascript_launch_contract_remains_enabled(self):
        argv = measurement.native_browser_arguments(SimpleNamespace(vox_javascript_mode='explicit', vox_chrome_height=84), '/tmp/document.png')
        self.assertIn('--enable-javascript', argv)
        self.assertEqual(argv[-1], measurement.URL)
        self.assertEqual(argv[argv.index('--window-width') + 1], '1024')
        self.assertEqual(argv[argv.index('--window-height') + 1], '852')

    def test_older_default_enabled_launch_selects_javascriptcore_without_new_switch(self):
        argv = measurement.native_browser_arguments(SimpleNamespace(vox_javascript_mode='default-enabled', vox_chrome_height=112), '/tmp/document.png')
        self.assertNotIn('--enable-javascript', argv)
        self.assertIn('--js-engine=javascriptcore', argv)
        self.assertEqual(argv[argv.index('--screenshot') + 1], '/tmp/document.png')
        self.assertNotIn('--disable-javascript', argv)
        self.assertEqual(argv[argv.index('--window-height') + 1], '880')

    def test_window_chrome_cannot_shrink_the_requested_document_viewport(self):
        with self.assertRaisesRegex(RuntimeError, 'chrome height must be nonnegative'):
            measurement.native_browser_arguments(SimpleNamespace(vox_javascript_mode='explicit', vox_chrome_height=-1), '/tmp/document.png')

    def test_unrecognized_javascript_contract_fails_before_a_launch(self):
        with self.assertRaisesRegex(RuntimeError, 'Unknown native JavaScript launch contract'):
            measurement.native_browser_arguments(SimpleNamespace(vox_javascript_mode='disabled'), '/tmp/document.png')

    def test_source_structure_change_is_not_silently_accepted(self):
        self.fixture = SyntheticFixture()
        self.fixture.body = self.fixture.body.replace(b'react-directory-row', b'other-row', 1)
        with self.assertRaisesRegex(RuntimeError, 'Unexpected fixture source structure'):
            measurement.source_expectations(self.fixture)

    def test_known_images_and_missing_offscreen_images_pass(self):
        self.assertTrue(measurement.content_gate(self.audit(), self.expected)['passed'])

    def test_wrong_filename_with_correct_count_fails(self):
        audit = self.audit()
        audit['selections'][1]['elements'][0]['text'] = 'fakefilename'
        self.assertFalse(measurement.content_gate(audit, self.expected)['passed'])

    def test_hidden_about_fails(self):
        audit = self.audit()
        audit['selections'][2]['elements'][0]['rect']['width'] = 0
        self.assertFalse(measurement.content_gate(audit, self.expected)['passed'])

    def test_hidden_first_row_fails(self):
        audit = self.audit()
        audit['selections'][0]['elements'][0]['rect']['y'] = 900
        self.assertFalse(measurement.content_gate(audit, self.expected)['passed'])

    def test_known_image_dimensions_required(self):
        audit = self.audit()
        audit['selections'][3]['elements'][0]['image']['natural_width'] = 0
        self.assertFalse(measurement.content_gate(audit, self.expected)['passed'])

    def test_unfinished_or_wrong_viewport_fails(self):
        audit = self.audit()
        audit['ready'] = 'interactive'
        audit['viewport_height'] = 852
        self.assertFalse(measurement.content_gate(audit, self.expected)['passed'])

    def test_brackets_exclude_straddling_samples(self):
        def row(start, end):
            return type('Reading', (), dict(sample_started=start, sample_completed=end))()
        history = [row(1, 2), row(3, 5), row(6, 7)]
        before, after = measurement.boundary_bracket(history, 4)
        self.assertIs(before, history[0])
        self.assertIs(after, history[2])
        with self.assertRaises(RuntimeError):
            measurement.boundary_bracket(history, 8)

    def ready_state(self, **changes):
        state = dict(url=measurement.URL, ready='complete', viewport_width=1024,
                     viewport_height=768, scale=1, fonts_status='loaded', known_images_ready=True)
        state.update(changes)
        return state

    def capture_with_states(self, states):
        events, checks = [], []
        expected = self.expected

        class Client:
            def call(self, method, params):
                if method == 'Runtime.evaluate':
                    # Fail immediately if any expensive semantic audit enters
                    # the measured helper, including a future accidental retry.
                    if params['expression'] != measurement.chrome_readiness_expression(expected):
                        raise AssertionError('semantic collection before counter stop')
                    events.append('readiness')
                    return dict(result=dict(value=measurement.json.dumps(states.pop(0))))
                if method != 'Page.captureScreenshot' or states:
                    raise AssertionError('capture before readiness')
                events.append('png')
                return dict(data='encoded-png')

        class Counter:
            def sample(self):
                events.append('counter')

        class Sampler:
            def __exit__(self, *args):
                events.append('stop')

        with patch.object(measurement.time, 'sleep'):
            image, endpoint, returned_checks = measurement.chrome_capture_endpoint(
                Client(), Counter(), Sampler(), expected, time.monotonic() + 10, 0, checks)
        self.assertIs(returned_checks, checks)
        self.assertEqual(image, dict(data='encoded-png'))
        self.assertLess(endpoint, time.monotonic())
        return events, checks

    def test_capture_samples_and_stops_before_any_semantic_audit(self):
        events, checks = self.capture_with_states([
            self.ready_state(ready='interactive'),
            self.ready_state(fonts_status='loading'),
            self.ready_state(known_images_ready=False), self.ready_state()])
        self.assertEqual(events, ['readiness'] * 4 + ['png', 'counter', 'stop'])
        self.assertEqual([check['passed'] for check in checks], [False, False, False, True])

    def test_readiness_requires_correct_location_scale_and_document_viewport(self):
        events, checks = self.capture_with_states([
            self.ready_state(url='about:blank'), self.ready_state(viewport_height=852),
            self.ready_state(scale=2), self.ready_state()])
        self.assertEqual(events[-3:], ['png', 'counter', 'stop'])
        self.assertEqual([check['passed'] for check in checks], [False, False, False, True])

    def test_readiness_does_not_collect_semantic_selectors_text_or_layout(self):
        expression = measurement.chrome_readiness_expression(self.expected)
        for expensive in ['querySelector', 'getBoundingClientRect', 'textContent', 'selections']:
            self.assertNotIn(expensive, expression)
        for url in self.expected['decoded_images']:
            self.assertIn(url, expression)

    def test_run_retains_mandatory_audit_after_png_and_counter_endpoint(self):
        # Protect the orchestration as well as the helper: a successful cheap
        # readiness check alone must never make an observation eligible.
        source = inspect.getsource(measurement.run_chrome)
        positions = [source.index(token) for token in [
            'chrome_capture_endpoint(', 'sampler = None',
            "result['png'] = png_info(png)", 'expression=chrome_audit_expression()',
            "require(gate['passed']", 'comparison_eligible=True)']]
        # The initial sampler declaration predates capture; find the stopping
        # assignment specifically after the capture helper call.
        positions[1] = source.index('sampler = None', positions[0])
        self.assertEqual(positions, sorted(positions))
        self.assertIn('audit_started >= end_after.sample_completed', source)
        self.assertFalse(measurement.AUDIT_POLICY['semantic_audits_inside_measurement'])
        self.assertTrue(measurement.AUDIT_POLICY['semantic_audits_required'])

    def test_png_requires_actual_document_dimensions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'document.png'
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + measurement.struct.pack('>II', 1024, 852))
            with self.assertRaises(RuntimeError):
                measurement.png_info(path)
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + measurement.struct.pack('>II', 1024, 768))
            self.assertEqual(measurement.png_info(path)['dimensions'], [1024, 768])

    def coalition_log(self):
        return '\n'.join('Vox coalition instructions: ' + measurement.json.dumps(row) for row in [
            dict(label='navigation_started', coalition_id=77, instructions=1000, tasks_started=2, tasks_exited=0),
            dict(label='capture_document_encoded', coalition_id=77, instructions=8000, tasks_started=3, tasks_exited=1)])

    def test_native_coalition_includes_departed_helpers(self):
        parsed = measurement.parse_native_coalitions(self.coalition_log(), 77)
        self.assertEqual(parsed['delta'], dict(instructions=7000, tasks_started=1, tasks_exited=1))

    def test_native_duplicate_and_missing_markers_rejected(self):
        text = self.coalition_log()
        for bad in [text + '\n' + text.splitlines()[0], text.splitlines()[0]]:
            with self.assertRaises(RuntimeError):
                measurement.parse_native_coalitions(bad, 77)

    def test_native_wrong_coalition_and_decreasing_counters_rejected(self):
        text = self.coalition_log()
        for bad, cid in [(text, 78), (text.replace('8000', '500'), 77),
                         (text.replace('"tasks_exited": 1', '"tasks_exited": 4'), 77)]:
            with self.assertRaises(RuntimeError):
                measurement.parse_native_coalitions(bad, cid)


class ProvenanceTests(unittest.TestCase):
    def test_build_receipt_requires_success_and_exact_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt, executable = Path(directory) / 'build.json', Path(directory) / 'Vox'
            executable.write_bytes(b'frozen executable')
            digest = hashlib.sha256(executable.read_bytes()).hexdigest()
            for value in [dict(exit=1, binary_sha256=digest), dict(exit=False, binary_sha256=digest),
                          dict(passed=True, build_complete=False, executable_sha256=digest),
                          dict(exit=0, binary_sha256='0' * 64)]:
                receipt.write_text(json.dumps(value))
                with self.subTest(receipt=value), self.assertRaises(RuntimeError):
                    measurement.build_provenance(receipt, executable)
            for value in [dict(exit=0, binary_sha256=digest),
                          dict(passed=True, build_complete=True, executable_sha256=digest)]:
                receipt.write_text(json.dumps(value))
                result = measurement.build_provenance(receipt, executable)
                self.assertEqual(result['sha256'], hashlib.sha256(receipt.read_bytes()).hexdigest())
                self.assertEqual(result['bytes'], receipt.stat().st_size)

    def test_ambient_controls_cannot_change_declared_native_gc_policy(self):
        inherited = dict(PATH='/bin', KEEP='yes', GC_MARKERS='9', GC_DISABLE='1',
                         JSC_useJIT='false', JSC_thresholdForJITAfterWarmUp='1',
                         GC_PRINT_STATS='1', VOX_PROFILE_CSS='1', DYLD_LIBRARY_PATH='/foreign',
                         SCREENSHOT_SETTLE_SECONDS='200', HTTPS_PROXY='http://proxy')
        args = SimpleNamespace(network_deny=Path('/deny.dylib'), work_dir=Path('/results'),
                               settle_seconds=.5, gc_markers=1)
        with patch.dict(os.environ, inherited, clear=True):
            self.assertEqual(measurement.clean_environment(), dict(PATH='/bin', KEEP='yes'))
            with self.assertRaisesRegex(RuntimeError, 'GC_DISABLE, GC_PRINT_STATS'):
                measurement.native_environment(args, Path('/results/pair-01.vox'))
            # Empty values can still enable presence-based collector flags.
            os.environ['GC_DISABLE'] = ''
            with self.assertRaisesRegex(RuntimeError, 'GC_DISABLE'):
                measurement.native_environment(args, Path('/results/pair-01.vox'))
            del os.environ['GC_DISABLE'], os.environ['GC_PRINT_STATS']
            env = measurement.native_environment(args, Path('/results/pair-01.vox'))
            self.assertEqual(env['GC_MARKERS'], '1')
            self.assertNotIn('GC_DISABLE', env)
            self.assertNotIn('GC_PRINT_STATS', env)
            for key in ['VOX_PROFILE_CSS',
                        'DYLD_LIBRARY_PATH', 'SCREENSHOT_SETTLE_SECONDS', 'HTTPS_PROXY']:
                self.assertEqual(env[key], '')
            self.assertEqual(env['DYLD_INSERT_LIBRARIES'], '/deny.dylib')
            self.assertEqual(env['LADYBIRD_CACHE_DIR'], '/results/pair-01.vox/cache')
            self.assertEqual(env['VOX_PROFILE_DIR'], '/results/pair-01.vox/profile')
            args.gc_markers = 2
            self.assertEqual(measurement.native_environment(args, Path('/results/pair-01.vox'))['GC_MARKERS'], '2')


class SharedBundleTests(unittest.TestCase):
    app = Path('/shared/Vox.app')

    def row(self, pid):
        return dict(pid=pid, parent=1, uid=os.getuid(),
                    command=str(self.app / 'Contents/MacOS/Vox') + ' --screenshot /private/capture.png')

    def proc(self, starts):
        return SimpleNamespace(
            read=lambda pid: SimpleNamespace(start=starts[pid], exited=False),
            path=lambda pid: str(self.app / 'Contents/MacOS/Vox'))

    def test_pin_existing_gui_without_requiring_an_idle_shared_bundle(self):
        gui = self.row(11)
        other = dict(self.row(12), command='/unrelated/App')
        with patch.object(measurement, 'processes', return_value=[gui, other]):
            self.assertEqual(measurement.existing_app_identities(self.proc({11: 100}), self.app),
                             [dict(gui, start_ticks=100)])

    def test_preexisting_process_disappearing_is_distinct_from_permission_failure(self):
        for code in (2, 3, 13):
            with self.subTest(errno=code), patch.object(measurement, 'processes', return_value=[self.row(11)]):
                proc = SimpleNamespace(read=lambda pid: (_ for _ in ()).throw(OSError(code, 'fixture')))
                if code == 13:
                    with self.assertRaises(OSError):
                        measurement.existing_app_identities(proc, self.app)
                else:
                    self.assertEqual(measurement.existing_app_identities(proc, self.app), [])

    def test_new_root_can_share_a_bundle_with_an_existing_gui(self):
        existing = [dict(self.row(11), start_ticks=100)]
        rows = measurement.validate_app_members(self.proc({22: 200}), self.app,
                                                [self.row(22)], existing)
        self.assertEqual([row['pid'] for row in rows], [22])
        self.assertEqual(rows[0]['start_ticks'], 200)
        self.assertEqual(rows[0]['executable'], str(self.app / 'Contents/MacOS/Vox'))

    def test_preexisting_gui_in_measured_coalition_is_rejected(self):
        existing = [dict(self.row(11), start_ticks=100)]
        with self.assertRaisesRegex(RuntimeError, 'preexisting browser task'):
            measurement.validate_app_members(self.proc({11: 100}), self.app, [self.row(11)], existing)

    def test_recycled_pid_is_compared_by_creation_identity(self):
        old = [dict(self.row(11), start_ticks=100)]
        rows = measurement.validate_app_members(self.proc({11: 200}), self.app, [self.row(11)], old)
        self.assertEqual(rows[0]['start_ticks'], 200)

    def test_argv_cannot_disguise_an_unrelated_executable(self):
        proc = self.proc({22: 200})
        proc.path = lambda pid: '/unrelated/app'
        with self.assertRaisesRegex(RuntimeError, 'unrelated executable'):
            measurement.validate_app_members(proc, self.app, [self.row(22)], [])

    def test_identity_churn_and_exited_members_fail_closed(self):
        for readings in [
            [SimpleNamespace(start=100, exited=False), SimpleNamespace(start=200, exited=False)],
            [SimpleNamespace(start=100, exited=False), SimpleNamespace(start=100, exited=True)],
        ]:
            with self.subTest(readings=readings):
                proc = self.proc({22: 100})
                proc.read = lambda pid: readings.pop(0)
                with self.assertRaisesRegex(RuntimeError, 'identity changed'):
                    measurement.validate_app_members(proc, self.app, [self.row(22)], [])

    def test_only_authenticated_members_are_adopted_by_memory_guard(self):
        members = measurement.validate_app_members(self.proc({22: 200}), self.app, [self.row(22)], [])
        with patch.object(measurement, 'publish_adopted_processes') as publish, \
                patch.object(measurement, 'read_adopted_processes', return_value={22: 'started'}):
            registry = Path('/private/pids.json')
            measurement.adopt_app_members(registry, members)
            publish.assert_called_once_with(registry, [22])

    def test_missing_memory_guard_adoption_is_an_error(self):
        with patch.object(measurement, 'publish_adopted_processes'), \
                patch.object(measurement, 'read_adopted_processes', return_value={}):
            with self.assertRaisesRegex(RuntimeError, 'did not register'):
                measurement.adopt_app_members(Path('/private/pids.json'), [dict(pid=22)])

    def test_shared_bundle_coalition_keeps_gui_outside_and_adopts_measured_root_and_helper(self):
        rows = [self.row(pid) for pid in (11, 22, 23)]
        groups = {11: 88, 22: 77, 23: 77}
        api = SimpleNamespace(resource_coalition=lambda pid: groups[pid],
                              read=lambda cid: CoalitionReading(cid, 1000, 2000, 2, 0, 1, 2))
        attempts = []
        with patch.object(measurement, 'processes', return_value=rows), \
                patch.object(measurement, 'adopt_app_members') as adopt:
            scan = measurement.native_membership(api, 77, self.app, 22, time.monotonic() + 1,
                attempts, self.proc({11: 100, 22: 200, 23: 201}),
                [dict(rows[0], start_ticks=100)], Path('/private/pids.json'))
        self.assertEqual([row['pid'] for row in scan['members']], [22, 23])
        self.assertEqual(adopt.call_args.args[1], scan['members'])
        self.assertEqual(len(attempts), 1)

    def test_shared_coalition_cannot_hide_preexisting_gui_behind_same_app_path(self):
        rows = [self.row(pid) for pid in (11, 22)]
        api = SimpleNamespace(resource_coalition=lambda pid: 77,
                              read=lambda cid: CoalitionReading(cid, 1000, 2000, 2, 0, 1, 2))
        with patch.object(measurement, 'processes', return_value=rows), \
                patch.object(measurement, 'adopt_app_members') as adopt:
            with self.assertRaisesRegex(RuntimeError, 'preexisting browser task'):
                measurement.native_membership(api, 77, self.app, 22, time.monotonic() + 1, [],
                    self.proc({11: 100, 22: 200}), [dict(rows[0], start_ticks=100)],
                    Path('/private/pids.json'))
        adopt.assert_not_called()

    def test_reused_existing_root_is_neither_adopted_nor_terminated(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture, folder = root / 'fixture', root / 'observation'
            fixture.mkdir()
            folder.mkdir()
            png = folder / 'document.png'
            existing = dict(self.row(11), command=str(self.app / 'Contents/MacOS/Vox')
                            + ' --screenshot ' + str(png))
            args = SimpleNamespace(vox=self.app / 'Contents/MacOS/Vox', fixture=fixture,
                network_deny=Path('/deny.dylib'), work_dir=root, settle_seconds=.5, gc_markers=1,
                vox_javascript_mode='explicit', vox_chrome_height=112, timeout=1,
                memory_guard_registry=root / 'pids.json')
            with patch.dict(os.environ, {}, clear=True), \
                    patch.object(measurement, 'SealedFixture'), \
                    patch.object(measurement, 'MacCoalitionCounters'), \
                    patch.object(measurement, 'MacCounters', return_value=self.proc({11: 100})), \
                    patch.object(measurement, 'processes', return_value=[existing]), \
                    patch.object(measurement.subprocess, 'run', return_value=SimpleNamespace(
                        returncode=0, stdout='', stderr='')) as launch, \
                    patch.object(measurement, 'adopt_app_members') as adopt, \
                    patch.object(measurement.os, 'kill') as kill:
                result = measurement.run_vox(args, folder, {}, 'fixture-hash')
            self.assertEqual(result['exit'], 1)
            self.assertIn('preexisting browser task', result['error'])
            self.assertTrue((folder / 'profile').is_dir())
            self.assertEqual(list((folder / 'profile').iterdir()), [])
            command = launch.call_args.args[0]
            self.assertEqual(command[:3], ['/usr/bin/open', '-n', '-g'])
            self.assertIn('VOX_PROFILE_DIR=' + str(folder / 'profile'), command)
            adopt.assert_not_called()
            kill.assert_not_called()

    def test_failed_adoption_cleans_up_only_the_verified_new_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture, folder = root / 'fixture', root / 'observation'
            fixture.mkdir()
            folder.mkdir()
            launched = dict(self.row(22), command=str(self.app / 'Contents/MacOS/Vox')
                            + ' --screenshot ' + str(folder / 'document.png'))
            args = SimpleNamespace(vox=self.app / 'Contents/MacOS/Vox', fixture=fixture,
                network_deny=Path('/deny.dylib'), work_dir=root, settle_seconds=.5, gc_markers=1,
                vox_javascript_mode='explicit', vox_chrome_height=112, timeout=1,
                memory_guard_registry=root / 'pids.json')
            with patch.dict(os.environ, {}, clear=True), \
                    patch.object(measurement, 'SealedFixture'), \
                    patch.object(measurement, 'MacCoalitionCounters'), \
                    patch.object(measurement, 'MacCounters', return_value=self.proc({22: 200})), \
                    patch.object(measurement, 'existing_app_identities',
                                 return_value=[dict(self.row(11), start_ticks=100)]), \
                    patch.object(measurement, 'processes', return_value=[launched]), \
                    patch.object(measurement.subprocess, 'run', return_value=SimpleNamespace(
                        returncode=0, stdout='', stderr='')), \
                    patch.object(measurement, 'adopt_app_members', side_effect=RuntimeError('adoption failed')), \
                    patch.object(measurement.os, 'kill') as kill:
                result = measurement.run_vox(args, folder, {}, 'fixture-hash')
            self.assertEqual(result['exit'], 1)
            self.assertEqual(result['error'], 'adoption failed')
            kill.assert_called_once_with(22, 15)


if __name__ == '__main__':
    unittest.main()
