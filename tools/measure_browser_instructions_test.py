import base64
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import measure_browser_instructions as measurement
from process_instruction_counts import Reading


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
                (profile / 'DevToolsActivePort').write_text('1234\n')
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


if __name__ == '__main__':
    unittest.main()
