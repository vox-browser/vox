import base64
import json
import io
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

    def test_signalling_a_live_process_preserves_permission_errors(self):
        process = Mock(pid=123, returncode=None)
        process.poll.return_value = None
        with patch.object(measurement.os, 'killpg', side_effect=PermissionError()):
            with self.assertRaises(PermissionError):
                measurement.stop_process(process)


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

    def test_full_direct_capture_never_navigates_or_resizes_and_audits_after_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(directory)
            state = dict(ready='complete', textLength=2022, sprites=21,
                         width=1024, height=768, scale=1)
            methods = []
            class Client:
                sock = Mock()
                def call(self, method, params=None):
                    methods.append(method)
                    if method == 'Runtime.evaluate':
                        expression = params['expression']
                        if 'document.fonts.ready' in expression:
                            return {'result': {'value': True}}
                        return {'result': {'value': json.dumps(state)}}
                    if method == 'Page.captureScreenshot':
                        return {'data': base64.b64encode(b'PNG payload').decode()}
                    return {'product': 'test Chrome'}
            client = Client()
            process = Mock(pid=1)
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
            counter.report.return_value = {'instructions': 100}
            sampler = Mock()
            sampler.__enter__ = Mock()
            sampler.__exit__ = Mock(return_value=False)
            with patch.object(measurement.subprocess, 'Popen', side_effect=launch), \
                    patch.object(measurement, 'ProcessTreeCounter', return_value=counter), \
                    patch.object(measurement, 'CounterSampler', return_value=sampler), \
                    patch.object(measurement, 'CDP', return_value=client), \
                    patch.object(measurement.urllib.request, 'build_opener', return_value=opener), \
                    patch.object(measurement, 'stop_process'):
                result = measurement.run_chrome(args, Path(directory) / 'capture', None)
            for forbidden in ['Page.navigate', 'Emulation.setDeviceMetricsOverride',
                              'Page.enable', 'Runtime.enable']:
                self.assertNotIn(forbidden, methods)
            self.assertGreater(methods.index('Browser.getVersion'), methods.index('Page.captureScreenshot'))
            self.assertEqual(result['chrome_launch_mode'], 'direct')
            self.assertNotIn('navigation_to_screenshot', result)
            self.assertNotIn('navigation_to_capture_observed_ms', result)
            self.assertEqual(Path(result['screenshot']).read_bytes(), b'PNG payload')
            counter.report.assert_called_once_with(snapshot=counter.snapshot_before.return_value)


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


if __name__ == '__main__':
    unittest.main()
