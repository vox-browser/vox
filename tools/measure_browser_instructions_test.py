import base64
import json
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import measure_browser_instructions as measurement
from process_instruction_counts import Reading


class ProcessStopTests(unittest.TestCase):
    def test_exited_capture_is_reaped_before_signalling_its_process_group(self):
        process = Mock(pid=123, returncode=None)
        process.poll.return_value = 0
        with patch.object(measurement.os, 'killpg') as kill:
            measurement.stop_process(process)
        kill.assert_not_called()

    def test_capture_exit_between_poll_and_signal_does_not_mask_its_results(self):
        process = Mock(pid=123, returncode=None)
        process.poll.side_effect = [None, 0]
        with patch.object(measurement.os, 'killpg', side_effect=PermissionError()):
            measurement.stop_process(process)
        process.wait.assert_called_once_with(timeout=3)

    def test_group_permission_failure_targets_only_the_original_child(self):
        process = Mock(pid=123, returncode=None)
        process.poll.return_value = None
        with patch.object(measurement.os, 'killpg', side_effect=PermissionError()):
            measurement.stop_process(process)
        process.terminate.assert_called_once_with()


class ChromeCaptureExitTests(unittest.TestCase):
    def test_shutdown_releases_the_observer_socket_before_waiting_for_browser_exit(self):
        client, process = Mock(), Mock()
        client.call.return_value = {'result': {'value': True}}
        def wait(timeout):
            client.sock.close.assert_called_once_with()
            return 0
        process.wait.side_effect = wait
        report = dict(instructions=123, endpoint='screenshot response')
        measurement.finish_chrome_capture(client, process, report, Path('/unused/capture'))
        self.assertEqual(report['instructions'], 123)
        self.assertEqual(report['endpoint'], 'screenshot response')
        self.assertEqual(report['exit'], 0)

    def test_shutdown_cancels_interception_after_preserving_capture_counters(self):
        client, process = Mock(), Mock()
        client.call.return_value = {'result': {'value': True}}
        process.wait.return_value = 0
        report = dict(instructions=123, endpoint='screenshot response')
        measurement.finish_chrome_capture(client, process, report, Path('/unused/capture'))
        self.assertEqual([call.args[0] for call in client.call.call_args_list],
                         ['Page.stopLoading', 'Fetch.disable', 'Page.navigate',
                          'Runtime.evaluate', 'Browser.close'])
        self.assertEqual(report['instructions'], 123)
        self.assertEqual(report['endpoint'], 'screenshot response')
        self.assertEqual(report['shutdown_cleanup_methods'],
                         ['Page.stopLoading', 'Fetch.disable', 'Page.navigate'])
        self.assertTrue(report['shutdown_blank_document_ready'])
        self.assertEqual(report['shutdown_cleanup_errors'], {})
        self.assertEqual(report['exit'], 0)
        self.assertFalse(report['shutdown_forced'])

    def test_blank_document_waits_for_navigation_before_browser_shutdown(self):
        client, process = Mock(), Mock()
        process.wait.return_value = 0
        states = iter([False, True])
        def respond(method, params=None):
            if method == 'Runtime.evaluate':
                return {'result': {'value': next(states)}}
            return {}
        client.call.side_effect = respond
        report = dict(instructions=456)
        with patch.object(measurement.time, 'sleep'):
            measurement.finish_chrome_capture(client, process, report, Path('/unused/capture'))
        self.assertTrue(report['shutdown_blank_document_ready'])
        self.assertEqual(report['instructions'], 456)
        self.assertEqual(client.call.call_args_list[-1].args, ('Browser.close',))

    def test_socket_eof_can_accompany_a_verified_clean_exit_after_capture(self):
        client = Mock()
        client.call.side_effect = EOFError()
        process = Mock()
        process.wait.return_value = 0
        report = dict(instructions=123, endpoint='screenshot response')
        measurement.finish_chrome_capture(client, process, report, Path('/unused/capture'))
        self.assertEqual(report['exit'], 0)
        self.assertFalse(report['shutdown_forced'])
        self.assertEqual(report['instructions'], 123)
        process.wait.assert_called_once_with(timeout=30)
        self.assertEqual(report['shutdown_timeout_seconds'], 30)
        self.assertGreaterEqual(report['shutdown_elapsed_seconds'], 0)

    def test_crash_retains_the_frozen_capture_counters_and_actual_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / 'capture'
            process = Mock()
            process.wait.return_value = -11
            with self.assertRaisesRegex(RuntimeError, 'exit -11'):
                measurement.finish_chrome_capture(Mock(), process, dict(instructions=123), prefix)
            saved = json.loads(Path(str(prefix) + '.failure.json').read_text())
            self.assertEqual(saved['exit'], -11)
            self.assertEqual(saved['instructions'], 123)
            self.assertFalse(saved['valid'])
            self.assertFalse(saved['shutdown_forced'])

    def test_timeout_forces_cleanup_and_never_overwrites_a_failure_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / 'capture'
            original = Path(str(prefix) + '.failure.json')
            original.write_text('original failure')
            process = Mock()
            process.wait.side_effect = subprocess.TimeoutExpired('Brave', 5)
            process.poll.return_value = -15
            with patch.object(measurement, 'stop_process') as stop:
                with self.assertRaisesRegex(RuntimeError, 'forced=True'):
                    measurement.finish_chrome_capture(Mock(), process, dict(instructions=123), prefix)
            stop.assert_called_once_with(process)
            self.assertEqual(original.read_text(), 'original failure')
            receipt = next(Path(directory).glob('capture.failure-*.json'))
            saved = json.loads(receipt.read_text())
            self.assertEqual(saved['instructions'], 123)
            self.assertEqual(saved['exit'], -15)
            self.assertTrue(saved['shutdown_forced'])


class ChromeDebuggerStartupTests(unittest.TestCase):
    def counter(self, exited=False):
        counter = Mock(root_identity=(1, 100))
        counter.sample.return_value = {(1, 100): Reading(1, 100, exited, 100, 200)}
        return counter

    def test_page_target_can_appear_after_debugger_without_resetting_counters(self):
        opener = Mock()
        opener.open.side_effect = [io.StringIO(json.dumps(targets)) for targets in
            [[], [{'type':'browser'}], [{'type':'page','webSocketDebuggerUrl':'ws://localhost/page'}]]]
        counter = self.counter()
        with patch.object(measurement.time, 'monotonic', return_value=0), \
                patch.object(measurement.time, 'sleep') as sleep:
            result = measurement.wait_for_chrome_page_target(opener, 1234, counter, 1, .005, 'chrome.log')
        self.assertEqual(result, 'ws://localhost/page')
        self.assertEqual(counter.sample.call_count, 2)
        self.assertEqual(sleep.call_count, 2)

    def test_absent_page_target_obeys_exit_and_deadline(self):
        for exited, now, message in [(True, 0, 'Chrome exited before page target'),
                                     (False, 2, 'Chrome page target did not start')]:
            opener = Mock()
            opener.open.return_value = io.StringIO('[]')
            with patch.object(measurement.time, 'monotonic', return_value=now), \
                    patch.object(measurement.time, 'sleep') as sleep:
                with self.assertRaisesRegex(RuntimeError, message):
                    measurement.wait_for_chrome_page_target(opener,1234,self.counter(exited),1,.005,'chrome.log')
            sleep.assert_not_called()

    def test_waits_for_both_lines_when_discovery_file_already_exists_empty(self):
        with tempfile.TemporaryDirectory() as directory:
            active = Path(directory) / 'DevToolsActivePort'
            active.write_text('')
            stages = iter(['1234\n', '1234\n/devtools/browser/',
                           '1234\n/devtools/browser/session-id\n'])
            counter = self.counter()
            with patch.object(measurement.time, 'monotonic', return_value=0), \
                    patch.object(measurement.time, 'sleep',
                                 side_effect=lambda _: active.write_text(next(stages))) as sleep:
                endpoint = measurement.wait_for_chrome_debugger(active, counter, 1, .005, 'chrome.log')
            self.assertEqual(endpoint, (1234, '/devtools/browser/session-id'))
            self.assertEqual(sleep.call_count, 3)
            self.assertEqual(counter.sample.call_count, 3)

    def test_rejects_missing_unreadable_and_invalid_discovery_contents(self):
        active = Mock()
        for text in ['', '1234\n', 'invalid\n/devtools/browser/id',
                     '0\n/devtools/browser/id', '65536\n/devtools/browser/id',
                     '1234\n/other/id', '1234\n/devtools/browser/',
                     '1234\n/devtools/browser/session id']:
            with self.subTest(text=text):
                active.read_text.return_value = text
                self.assertIsNone(measurement.chrome_debugger_endpoint(active))
        for error in [FileNotFoundError(), PermissionError(), UnicodeError()]:
            with self.subTest(error=error):
                active.read_text.side_effect = error
                self.assertIsNone(measurement.chrome_debugger_endpoint(active))

    def test_partial_file_still_observes_process_exit(self):
        active = Mock()
        active.read_text.return_value = '1234\n'
        with patch.object(measurement.time, 'monotonic', return_value=0), \
                patch.object(measurement.time, 'sleep') as sleep:
            with self.assertRaisesRegex(RuntimeError, 'Chrome exited before debugger startup'):
                measurement.wait_for_chrome_debugger(active, self.counter(exited=True),
                                                     1, .005, 'chrome.log')
        sleep.assert_not_called()

    def test_empty_file_still_obeys_watchdog_without_relaunching(self):
        active = Mock()
        active.read_text.return_value = ''
        counter = self.counter()
        with patch.object(measurement.time, 'monotonic', side_effect=[0, .5, 1.1]), \
                patch.object(measurement.time, 'sleep') as sleep:
            with self.assertRaisesRegex(RuntimeError, 'before the watchdog'):
                measurement.wait_for_chrome_debugger(active, counter, 1, .005, 'chrome.log')
        self.assertEqual(counter.sample.call_count, 2)
        self.assertEqual(sleep.call_count, 2)


class ChromeDirectLaunchTests(unittest.TestCase):
    def args(self, directory, direct=True):
        return SimpleNamespace(binary=Path('/test/Chrome'), scratch_dir=directory,
                               timeout=5, width=1024, height=768,
                               url='http://127.0.0.1:49171/', sample_interval=.005,
                               expect_sprites=21, expect_text_length=2022,
                               chrome_launch_mode='direct' if direct else 'blank',
                               chrome_outer_window_height=911 if direct else None)

    def test_direct_argv_installs_initial_geometry_and_url_without_blank_page(self):
        args = self.args('/scratch')
        command = measurement.chrome_launch_command(args, args.binary, '/fresh-profile')
        self.assertEqual(command[-2:], ['--window-size=1024,911', args.url])
        self.assertNotIn('about:blank', command)
        self.assertIn('--user-data-dir=/fresh-profile', command)
        self.assertNotIn('--hide-scrollbars', command)

    def test_historical_blank_launch_still_configures_viewport(self):
        args = self.args('/scratch', direct=False)
        command = measurement.chrome_launch_command(args, args.binary, '/fresh-profile')
        self.assertEqual(command[-1], 'about:blank')
        self.assertFalse(any(part.startswith('--window-size=') for part in command))
        client = Mock()
        measurement.prepare_chrome_target(client, args)
        self.assertEqual([call.args[0] for call in client.call.call_args_list],
                         ['Browser.getVersion', 'Page.enable', 'Runtime.enable',
                          'Emulation.setDeviceMetricsOverride'])

    def test_disabled_author_scripts_are_installed_during_blank_setup(self):
        args = self.args('/scratch', direct=False)
        args.chrome_disable_javascript = True
        client = Mock()
        measurement.prepare_chrome_target(client, args)
        calls = client.call.call_args_list
        self.assertEqual(calls[-1].args,
                         ('Emulation.setScriptExecutionDisabled', {'value': True}))
        self.assertLess([c.args[0] for c in calls].index('Emulation.setDeviceMetricsOverride'),
                        [c.args[0] for c in calls].index('Emulation.setScriptExecutionDisabled'))
        self.assertNotIn('Page.navigate', [c.args[0] for c in calls])

    def test_disabled_author_scripts_reject_direct_launch_before_process_start(self):
        args = self.args('/scratch')
        args.chrome_disable_javascript = True
        with self.assertRaisesRegex(ValueError, 'policy precedes navigation'):
            measurement.chrome_launch_command(args, args.binary, '/fresh-profile')

    def test_cli_rejects_javascript_policy_without_chrome_blank_launch(self):
        for options in [[], ['--engine', 'chrome', '--chrome-launch-mode', 'direct',
                             '--chrome-outer-window-height', '911']]:
            with self.subTest(options=options):
                result = subprocess.run([sys.executable, str(Path(measurement.__file__)),
                                         '--chrome-disable-javascript', *options],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('policy precedes navigation', result.stderr)

    def test_direct_viewport_guard_rejects_browser_chrome_height_and_retina_scale(self):
        args = self.args('/scratch')
        measurement.validate_direct_chrome_viewport(args, {'width': 1024, 'height': 768, 'scale': 1})
        for width, height, scale in [(1024, 625, 1), (1024, 768, 2), (800, 768, 1)]:
            with self.subTest(width=width, height=height, scale=scale):
                with self.assertRaisesRegex(RuntimeError, 'never resizes'):
                    measurement.validate_direct_chrome_viewport(
                        args, {'width': width, 'height': height, 'scale': scale})

    def test_direct_cli_requires_an_explicit_outer_height(self):
        result = subprocess.run([sys.executable, str(Path(measurement.__file__)),
                                 '--engine', 'chrome', '--chrome-launch-mode', 'direct'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('positive --chrome-outer-window-height', result.stderr)

    def assert_full_capture(self, direct, settle_seconds=0, custom_readiness=False):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(directory, direct=direct)
            args.settle_seconds = settle_seconds
            if custom_readiness:
                args.chrome_readiness_expression = 'custom readiness'
            state = dict(ready='complete', textLength=2022, sprites=21,
                         width=1024, height=768, scale=1)
            methods = []
            readiness = []
            class Client:
                sock = Mock()
                def call(self, method, params=None):
                    methods.append(method)
                    if method == 'Runtime.evaluate':
                        expression = params['expression']
                        if 'document.fonts.ready' in expression:
                            return {'result': {'value': True}}
                        if expression == 'location.href === "about:blank" && document.readyState === "complete"':
                            return {'result': {'value': True}}
                        if expression == 'custom readiness':
                            readiness.append(True)
                            return {'result': {'value': json.dumps(dict(state,
                                captureReady=len(readiness) > 1))}}
                        return {'result': {'value': json.dumps(state)}}
                    if method == 'Page.captureScreenshot':
                        return {'data': base64.b64encode(b'PNG payload').decode()}
                    return {'product': 'test Chrome'}
            client = Client()
            process = Mock(pid=1)
            process.wait.return_value = 0
            def launch(command, **kwargs):
                profile = Path(next(part.split('=', 1)[1] for part in command
                                    if part.startswith('--user-data-dir=')))
                (profile / 'DevToolsActivePort').write_text('1234\n/devtools/browser/session-id\n')
                return process
            response = Mock()
            response.__enter__ = Mock(return_value=response)
            response.__exit__ = Mock(return_value=False)
            response.read.return_value = json.dumps([
                {'type': 'page', 'webSocketDebuggerUrl': 'ws://127.0.0.1:1234/page'}]).encode()
            opener = Mock()
            opener.open.return_value = response
            counter = Mock(root_identity=(1, 100))
            counter.sample.return_value = {(1, 100): Reading(1, 100, False, 100, 200)}
            counter.snapshot_before.return_value = SimpleNamespace(sampled_at=0)
            counter.report.side_effect = lambda baseline=None, **kwargs: {
                'instructions': 300 if baseline is not None else 1000}
            sampler = Mock()
            sampler.__enter__ = Mock()
            sampler.__exit__ = Mock(return_value=False)
            with patch.object(measurement.subprocess, 'Popen', side_effect=launch), \
                    patch.object(measurement, 'ProcessTreeCounter', return_value=counter), \
                    patch.object(measurement, 'CounterSampler', return_value=sampler), \
                    patch.object(measurement, 'CDP', return_value=client), \
                    patch.object(measurement.urllib.request, 'build_opener', return_value=opener), \
                    patch.object(measurement, 'stop_process'), \
                    patch.object(measurement.time, 'sleep', side_effect=lambda seconds: methods.append(('settle', seconds))):
                result = measurement.run_chrome(args, Path(directory) / 'capture', None)
            if direct:
                capture_methods = methods[:methods.index('Page.stopLoading')]
                self.assertNotIn('Page.navigate', capture_methods)
                self.assertEqual(methods.count('Page.navigate'), 1, 'Only teardown may navigate')
                for forbidden in ['Emulation.setDeviceMetricsOverride', 'Page.enable', 'Runtime.enable']:
                    self.assertNotIn(forbidden, methods)
                self.assertGreater(methods.index('Browser.getVersion'), methods.index('Page.captureScreenshot'))
                self.assertNotIn('navigation_to_screenshot', result)
                self.assertNotIn('navigation_to_capture_observed_ms', result)
                counter.report.assert_called_once_with(snapshot=counter.snapshot_before.return_value)
            else:
                self.assertIn('Page.navigate', methods)
                self.assertEqual(result['navigation_to_screenshot']['instructions'], 300)
                self.assertEqual(counter.report.call_count, 2)
            self.assertEqual(result['instructions'], 1000, 'Primary counts must include startup')
            self.assertEqual(result['settle_seconds'], settle_seconds)
            if custom_readiness:
                self.assertEqual(len(readiness), 2)
                self.assertTrue(result['document']['captureReady'])
                self.assertEqual(methods.count('Page.captureScreenshot'), 1)
            if settle_seconds:
                self.assertLess(methods.index('Runtime.evaluate'), methods.index(('settle', settle_seconds)))
                self.assertLess(methods.index(('settle', settle_seconds)), methods.index('Page.captureScreenshot'))
            self.assertEqual(result['exit'], 0)
            self.assertFalse(result['shutdown_forced'])
            self.assertEqual(result['chrome_launch_mode'], 'direct' if direct else 'blank')
            self.assertEqual(Path(result['screenshot']).read_bytes(), b'PNG payload')

    def test_full_direct_capture_never_navigates_or_resizes_and_audits_after_boundary(self):
        self.assert_full_capture(direct=True)

    def test_blank_capture_keeps_startup_in_primary_totals_and_navigation_separate(self):
        self.assert_full_capture(direct=False)

    def test_settlement_precedes_png_and_remains_in_launch_counts(self):
        self.assert_full_capture(direct=False, settle_seconds=2)

    def test_custom_content_readiness_must_succeed_before_capture(self):
        self.assert_full_capture(direct=False, custom_readiness=True)


class CaptureEnvironmentTests(unittest.TestCase):
    def test_uninstrumented_run_removes_even_empty_native_getenv_controls(self):
        args = SimpleNamespace(timeout=90, settle_seconds=2, native_instruction_markers=False)
        for marker in ('', '1'):
            with patch.dict(os.environ, dict(VOX_PROFILE_INSTRUCTIONS=marker,
                    LADYBIRD_DEBUG_TIMING='1', GC_PRINT_STATS='1')):
                env = measurement.native_capture_environment(args)
            for key in ('VOX_PROFILE_INSTRUCTIONS', 'LADYBIRD_DEBUG_TIMING', 'GC_PRINT_STATS'):
                self.assertNotIn(key, env)
            self.assertEqual(env['LADYBIRD_SCREENSHOT_DELAY_SECONDS'], '2.0')

    def test_legacy_callers_keep_explicit_native_diagnostic_markers(self):
        env = measurement.native_capture_environment(SimpleNamespace(timeout=90))
        self.assertEqual(env['VOX_PROFILE_INSTRUCTIONS'], '1')
        self.assertEqual(env['LADYBIRD_SCREENSHOT_DELAY_SECONDS'], '0.0')

    def test_settlement_rejects_invalid_or_unbounded_values_before_launch(self):
        for seconds in (-1, 90, float('nan'), float('inf')):
            args = SimpleNamespace(timeout=90, settle_seconds=seconds)
            with self.subTest(seconds=seconds), self.assertRaises(ValueError):
                measurement.native_capture_environment(args)


class VoxLaunchArgumentTests(unittest.TestCase):
    def args(self):
        return SimpleNamespace(binary=Path('/test/Vox'), timeout=5, width=1024, height=768,
                               url='http://127.0.0.1:49171/', sample_interval=.005)

    def test_default_argv_reserves_the_compact_browser_chrome(self):
        args = self.args()
        self.assertEqual(measurement.vox_launch_command(args, args.binary, '/capture.png'),
                         ['/test/Vox', '--window-width', '1024', '--window-height', '852',
                          '--screenshot', '/capture.png', args.url])

    def test_explicit_options_remain_literal_and_precede_capture_and_url(self):
        args = self.args()
        args.vox_arg = ['--enable-javascript', '--js-engine=javascriptcore', 'literal $(text)']
        command = measurement.vox_launch_command(args, args.binary, '/capture.png')
        self.assertEqual(command[1:4], args.vox_arg)
        self.assertEqual(command[-1], args.url)
        self.assertGreater(command.index('--window-width'), command.index('--enable-javascript'))

    def test_cli_rejects_vox_launch_arguments_for_chrome(self):
        result = subprocess.run([sys.executable, str(Path(measurement.__file__)),
                                 '--engine', 'chrome', '--vox-arg=--enable-javascript'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('--vox-arg requires engine vox', result.stderr)

    def test_full_vox_capture_passes_policy_and_samples_exit_before_reaping(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args()
            args.vox_arg = ['--enable-javascript', '--js-engine=javascriptcore']
            args.native_instruction_markers = False
            args.settle_seconds = 2
            prefix = Path(directory) / 'capture'
            process = Mock(pid=1)
            events = []
            process.wait.side_effect = lambda: events.append('wait') or 0
            counter = Mock(root_identity=(1, 100))
            counter.sample.return_value = {(1, 100): Reading(1, 100, True, 100, 200)}
            counter.report.side_effect = lambda: events.append('report') or {'instructions': 100}
            def launch(command, **kwargs):
                Path(command[command.index('--screenshot') + 1]).write_bytes(b'native image')
                self.assertEqual(command[1:3], args.vox_arg)
                self.assertEqual(command[-1], args.url)
                self.assertEqual(kwargs['cwd'], measurement.REPO)
                self.assertNotIn('VOX_PROFILE_INSTRUCTIONS', kwargs['env'])
                self.assertEqual(kwargs['env']['LADYBIRD_SCREENSHOT_DELAY_SECONDS'], '2.0')
                return process
            def crop(source, target, width, height):
                self.assertEqual((width, height), (1024, 768))
                self.assertEqual(source.read_bytes(), b'native image')
                target.write_bytes(b'cropped viewport')
            with patch.object(measurement.subprocess, 'Popen', side_effect=launch), \
                    patch.object(measurement, 'ProcessTreeCounter', return_value=counter), \
                    patch.object(measurement, 'crop_document_viewport', side_effect=crop), \
                    patch.object(measurement, 'stop_process'):
                result = measurement.run_vox(args, prefix, None)
            self.assertEqual(events, ['report', 'wait'])
            self.assertEqual(result['command'][1:3], args.vox_arg)
            self.assertEqual(result['exit'], 0)
            self.assertEqual(result['instructions'], 100)
            self.assertEqual(Path(result['screenshot']).read_bytes(), b'cropped viewport')


class LinuxCaptureTests(unittest.TestCase):
    def args(self):
        return SimpleNamespace(binary=Path('/test/vox'), timeout=5, width=3, height=4,
                               url='http://127.0.0.1:49171/questions', counter_backend='callgrind',
                               scratch_dir=None, settle_seconds=2, expect_title='Questions',
                               expected_png=None, capture_audit_config=None)

    def audit(self, args):
        return dict(url=args.url, ready='complete', fully_active=True, title='Questions',
                    viewport_width=args.width, viewport_height=args.height, paint_commands=10)

    def test_linux_crop_removes_verified_sixty_pixel_chrome_and_checks_every_color_channel(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as directory:
            window = Path(directory) / 'window.png'
            viewport = Path(directory) / 'viewport.png'
            expected = Path(directory) / 'expected.png'
            image = Image.new('RGBA', (3, 88), 'red')
            image.paste((10, 20, 30, 255), (0, 60, 3, 64))
            image.save(window)
            with patch.object(measurement.platform, 'system', return_value='Linux'), \
                    patch.object(measurement.subprocess, 'run') as sips:
                measurement.crop_document_viewport(window, viewport, 3, 4)
            sips.assert_not_called()
            Image.new('RGBA', (3, 4), (10, 20, 30, 255)).save(expected)
            self.assertTrue(measurement.validate_screenshot(viewport, expected, 3, 4)['exact'])
            # Opaque alpha must not hide an RGB mismatch in Image.getbbox().
            Image.new('RGBA', (3, 4), (11, 20, 30, 255)).save(expected)
            with self.assertRaisesRegex(RuntimeError, 'pixels differ'):
                measurement.validate_screenshot(viewport, expected, 3, 4)

    def test_capture_audit_rejects_wrong_document_incomplete_readiness_and_viewport(self):
        args = self.args()
        measurement.validate_capture_audit(self.audit(args), args)
        for changes in ({'url': 'about:blank'}, {'ready': 'loading'}, {'fully_active': False},
                        {'viewport_height': 3}, {'title': 'Network error'}, {'paint_commands': 0}):
            with self.subTest(changes=changes), self.assertRaises(RuntimeError):
                measurement.validate_capture_audit({**self.audit(args), **changes}, args)

    def test_linux_launch_pins_viewport_and_keeps_literal_arguments(self):
        args = self.args()
        args.vox_arg = ['--enable-javascript', 'literal $(text)']
        command = measurement.vox_launch_command(args, args.binary, '/out.png')
        self.assertEqual(command[:3], ['/test/vox', '--screenshot-viewport-height', '4'])
        self.assertEqual(command[3:5], args.vox_arg)
        self.assertEqual(command[command.index('--window-height') + 1], '88')
        self.assertEqual(command[-1], args.url)

    def test_linux_capture_isolated_inputs_and_explicit_metric_survive_validation(self):
        from PIL import Image
        for backend in ('callgrind', 'cachegrind'):
            with self.subTest(backend=backend), tempfile.TemporaryDirectory() as directory:
                args = self.args()
                args.counter_backend = backend
                prefix = Path(directory) / 'capture'
                def execute(command, **kwargs):
                    Path(kwargs['log_path']).write_text('')
                    self.assertNotIn('VOX_PROFILE_INSTRUCTIONS', kwargs['env'])
                    self.assertEqual(kwargs['env']['SCREENSHOT_SETTLE_SECONDS'], '2')
                    self.assertTrue(Path(kwargs['env']['VOX_PROFILE_DIR']).is_dir())
                    self.assertTrue(Path(kwargs['env']['LADYBIRD_CACHE_DIR']).is_dir())
                    Image.new('RGB', (3, 88), 'green').save(command[command.index('--screenshot') + 1])
                    Path(kwargs['env']['VOX_CAPTURE_AUDIT_PATH']).write_text(json.dumps(self.audit(args)))
                    return {'instructions': 123, 'hardware_retired': False,
                            'instruction_metric': backend + '_guest_instruction_references'}
                with patch.object(measurement, 'run_' + backend + '_command', side_effect=execute), \
                        patch.object(measurement, 'run_perf_command') as perf, \
                        patch.object(measurement.platform, 'system', return_value='Linux'):
                    report = measurement.run_vox_linux(args, prefix)
                perf.assert_not_called()
                self.assertFalse(report['hardware_retired'])
                self.assertEqual(report['instruction_metric'], backend + '_guest_instruction_references')
                self.assertEqual(report['document_audit']['title'], 'Questions')
                self.assertEqual(report['cache_policy'], 'fresh empty cache')
                self.assertTrue(Path(report['screenshot']).is_file())

    def test_renderer_errors_fail_even_when_process_exit_and_document_are_valid(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'native.log'
            path.write_text('sokol.memory.slog | const_tag: sapp, level: 2, item_id: 50, '
                            'message: LINUX_X11_QUERY_SYSTEM_DPI_FAILED\n')
            measurement.validate_linux_renderer_log(path)
            for error in ['SAMPLER_POOL_EXHAUSTED', 'VALIDATE_ABND_FS_EXPECTED_SAMPLER_BINDING']:
                path.write_text('sokol.memory.slog | const_tag: sg, level: 1, item_id: 97, '
                                f'message: {error}\n')
                with self.subTest(error=error), self.assertRaisesRegex(RuntimeError, error):
                    measurement.validate_linux_renderer_log(path)

    def test_a_previous_screenshot_and_audit_cannot_validate_an_empty_new_run(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / 'capture'
            Path(str(prefix) + '.window.png').write_bytes(b'stale PNG')
            original = json.dumps(self.audit(self.args()))
            Path(str(prefix) + '.audit.json').write_text(original)
            with patch.object(measurement, 'run_callgrind_command') as run, \
                    self.assertRaisesRegex(RuntimeError, 'evidence already exists'):
                measurement.run_vox_linux(self.args(), prefix)
            run.assert_not_called()
            self.assertEqual(Path(str(prefix) + '.window.png').read_bytes(), b'stale PNG')
            self.assertEqual(Path(str(prefix) + '.audit.json').read_text(), original)


if __name__ == '__main__':
    unittest.main()
