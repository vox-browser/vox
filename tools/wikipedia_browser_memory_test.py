import ctypes
import errno
import threading
import time
import os
import copy
import struct
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace

from process_instruction_counts import RusageInfoV4
from wikipedia_browser_memory import (BackgroundControl, PhysicalTree, URL, audit_timing,
    clean_environment, drain_replay, require_png_scale, settled_reduction, summarize,
    validate_chrome_targets, validate_vox_document, vox_environment)


class WikipediaMemoryTests(unittest.TestCase):
    def test_settling_drains_buffered_and_late_replay_events_without_evaluation(self):
        calls = []
        client = SimpleNamespace(pending=bytearray(b'event'), sock=object())
        def pump():
            calls.append('pump')
            client.pending.clear()
        client.pump = pump
        client.call = lambda *_: self.fail('Unexpected Runtime evaluation while settling')
        with patch('wikipedia_browser_memory.select.select', side_effect=[([client.sock], [], []), ([], [], [])]):
            drain_replay(client)
        self.assertEqual(calls, ['pump', 'pump'])

    def test_native_environment_sets_explicit_raster_scale_and_clears_inherited_controls(self):
        inherited = {'HOME': '/home/test', 'PATH': '/bin', 'VOX_DISABLE_ADBLOCK': '1',
            'LADYBIRD_SCREENSHOT_SCALE': '.5', 'LADYBIRD_SCREENSHOT_DELAY_SECONDS': '0',
            'GC_FREE_SPACE_DIVISOR': '1', 'JSC_useJIT': 'false',
            'DYLD_INSERT_LIBRARIES': '/foreign.dylib', 'MTL_CAPTURE_ENABLED': '1',
            'SKIA_RENDERER': 'other', 'HTTP_PROXY': 'http://proxy.invalid'}
        sanitized = clean_environment(inherited)
        self.assertEqual(sanitized, dict(HOME='/home/test', PATH='/bin',
            VOX_TEST_WINDOW='1', VOX_COOKIE_FILE=''))
        args = SimpleNamespace(vox=Path('/private/Vox.app/Contents/MacOS/Vox'),
            network_deny=Path('/private/deny.dylib'), settle=15, diagnostic_gc_stats=False)
        with patch.dict(os.environ, inherited, clear=True):
            env = vox_environment(args, Path('/private/cache'), {'scale': 2}, Path('/private/run'))
        self.assertEqual(env['LADYBIRD_SCREENSHOT_SCALE'], '2')
        self.assertEqual(env['LADYBIRD_SCREENSHOT_DELAY_SECONDS'], '17')
        self.assertEqual(env['VOX_CAPTURE_AUDIT_PATH'], '/private/run.capture.json')
        self.assertEqual(env['DYLD_INSERT_LIBRARIES'], '/private/deny.dylib')
        self.assertNotIn('VOX_DISABLE_ADBLOCK', env)
        self.assertNotIn('GC_FREE_SPACE_DIVISOR', env)

    def test_raster_gate_rejects_logical_pixel_capture_for_retina_comparison(self):
        with tempfile.TemporaryDirectory() as temporary:
            p = Path(temporary) / 'raw.png'
            p.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + struct.pack('!II', 2048, 1760))
            self.assertEqual(require_png_scale(p, 1024, 880, 2), (2048, 1760))
            p.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + struct.pack('!II', 1024, 880))
            with self.assertRaisesRegex(RuntimeError, 'raster dimensions'):
                require_png_scale(p, 1024, 880, 2)

    def test_ready_endpoint_uses_audit_time_and_rejects_delayed_or_future_observation(self):
        result = audit_timing(10, 1_000_000_000, 2_000_000_000, 11.1, 15)
        self.assertEqual(result['endpoint_seconds'], 16)
        self.assertEqual(result['screenshot_earliest_seconds'], 18)
        self.assertAlmostEqual(result['observation_lag_seconds'], .1)
        for observed in [10.8, 11.6]:
            with self.assertRaisesRegex(RuntimeError, 'timestamp/observation lag'):
                audit_timing(10, 1_000_000_000, 2_000_000_000, observed, 15)

    def valid_document(self):
        return dict(url=URL, ready='complete', viewport_width=1024, viewport_height=768,
            paint_commands=836, javascript_diagnostics=[], fonts_status='unmaterialized', font_faces=[],
            selections=[dict(name='body', count=1, elements=[dict(text_utf8_bytes=6000)]),
                dict(name='root', count=1, elements=[dict(attributes={'class': 'no-js'})]),
                dict(name='sprites', count=21, elements=[]),
                dict(name='globe', count=1, elements=[dict(image=dict(model_present=True,
                    complete=True, current_src=URL+'portal/wikipedia.org/assets/img/Wikipedia-logo-v2@2x.png',
                    natural_width=200, natural_height=183, paint_decoded=False))])])

    def test_retained_document_gate_rejects_blank_or_incomplete_density_and_pending_fonts(self):
        # A selected srcset bitmap may bypass the literal-src paint cache.
        document = self.valid_document()
        validate_vox_document(document)
        for mutation in [lambda d: d.update(paint_commands=0),
                         lambda d: d.update(fonts_status='loading'),
                         lambda d: d['selections'][0]['elements'][0].update(text_utf8_bytes=0),
                         lambda d: d['selections'][2].update(count=0),
                         lambda d: d['selections'][3]['elements'][0]['image'].update(complete=False),
                         lambda d: d['selections'][3]['elements'][0]['image'].update(current_src=URL+'1x.png'),
                         lambda d: d['selections'][3]['elements'][0]['image'].update(natural_width=400)]:
            bad = copy.deepcopy(document)
            mutation(bad)
            with self.assertRaises(RuntimeError):
                validate_vox_document(bad)

    def test_chrome_gate_rejects_extra_blank_or_welcome_page_targets(self):
        valid = dict(targetInfos=[dict(type='page', url=URL), dict(type='browser', url='')])
        validate_chrome_targets(valid)
        for pages in [[dict(type='page', url=URL), dict(type='page', url='about:blank')],
                      [dict(type='page', url='chrome://welcome')], []]:
            with self.assertRaisesRegex(RuntimeError, 'exactly one'):
                validate_chrome_targets(dict(targetInfos=pages))

    def test_background_policy_restores_anchor_then_requires_stable_inactivity(self):
        state = {'active': True}
        restored = []
        def restore(pid):
            restored.append(pid)
            state['active'] = False
            return {'active': True}
        control = BackgroundControl(10, 20,
            inspect=lambda pid: {'pid': pid, 'active': state['active']}, restore=restore)
        for second in range(5):
            control.poll(second)
        self.assertEqual(restored, [20])
        self.assertEqual(control.verify_steady(4), [2, 4])
        state['active'] = True
        control.poll(5)
        with self.assertRaisesRegex(RuntimeError, 'became active'):
            control.verify_steady(5)

    def test_reparented_helper_remains_counted_and_reused_pid_is_excluded(self):
        state = {'round': 0}
        tasks = {1: (100, 100), 2: (200, 200), 3: (300, 300)}
        def read(pid, flavor, pointer):
            if pid == 3 and state['round'] == 2:
                ctypes.set_errno(errno.ESRCH)
                return -1
            usage = ctypes.cast(pointer, ctypes.POINTER(RusageInfoV4)).contents
            usage.ri_proc_start_abstime, usage.ri_phys_footprint = tasks[pid]
            usage.ri_lifetime_max_phys_footprint = 1000 + pid
            usage.ri_resident_size = 99999
            return 0
        api = SimpleNamespace(lib=SimpleNamespace(proc_pid_rusage=read),
            path=lambda pid: f'process-{pid}',
            children=lambda pid: {1: [2, 3] if state['round'] == 0 else [], 2: [3], 3: []}[pid])
        counter = PhysicalTree(1, time.monotonic(), api)
        counter.sample()
        self.assertEqual(counter.samples[-1]['physical_footprint_bytes'], 600)
        self.assertEqual(len(counter.samples[-1]['processes']), 3)
        state['round'] = 1
        counter.sample()
        self.assertEqual(counter.samples[-1]['physical_footprint_bytes'], 600)
        tasks[2] = (999, 9999999)
        state['round'] = 2
        counter.sample()
        self.assertEqual(counter.samples[-1]['physical_footprint_bytes'], 100)
        self.assertEqual(counter.samples[-1]['reused_pids_excluded'], [2])
        self.assertIn(3, counter.samples[-1]['vanished_during_sample'])

    def test_permission_errors_are_not_silently_removed_from_tree(self):
        def read(*_):
            ctypes.set_errno(errno.EPERM)
            return -1
        counter = PhysicalTree(1, time.monotonic(), SimpleNamespace(lib=SimpleNamespace(proc_pid_rusage=read)))
        with self.assertRaises(PermissionError):
            counter.sample()

    def test_current_simultaneous_peak_is_not_sum_of_lifetime_maxima(self):
        rows = []
        for i in range(31):
            processes = [dict(pid=1, start_ticks=1, physical_footprint_bytes=100,
                             task_lifetime_peak_bytes=1000),
                         dict(pid=2, start_ticks=2, physical_footprint_bytes=200 + i,
                             task_lifetime_peak_bytes=2000)]
            rows.append(dict(seconds=i / 10, physical_footprint_bytes=300 + i, processes=processes))
        rows.append(dict(seconds=3.1, physical_footprint_bytes=999999, processes=[dict(pid=1)]))
        result = summarize(rows, 3)
        self.assertEqual(result['settled_physical_footprint_bytes'], 325)
        self.assertEqual(result['observed_simultaneous_peak_bytes'], 330)
        self.assertEqual(result['task_lifetime_peak_sum_envelope_bytes'], 3000)
        self.assertEqual(result['observed_peak_seconds'], 3)

    def test_missing_samples_and_stale_final_sample_fail(self):
        with self.assertRaisesRegex(RuntimeError, 'Insufficient'):
            summarize([], 2)
        rows = [dict(seconds=i / 100, processes=[{}]) for i in range(20)]
        with self.assertRaisesRegex(RuntimeError, 'too far'):
            summarize(rows, 1)

    def test_seventy_percent_gate_uses_ratio_of_browser_medians(self):
        def row(value):
            return dict(memory=dict(settled_physical_footprint_bytes=value,
                                    observed_simultaneous_peak_bytes=value + 10))
        result = settled_reduction([row(29), row(29.5), row(29.7)], [row(99), row(100), row(101)])
        self.assertTrue(result['target_met'])
        self.assertEqual(result['vox_target_bytes'], 30)
        self.assertAlmostEqual(result['strict_vox_target_bytes'], 29.7)
        self.assertAlmostEqual(result['settled_reduction'], .705)
        borderline = settled_reduction([row(29), row(30), row(31)], [row(99), row(100), row(101)])
        self.assertTrue(borderline['median_target_met'])
        self.assertFalse(borderline['target_met'])
        self.assertFalse(settled_reduction([row(30.1)], [row(100)])['target_met'])
        with self.assertRaises(ValueError):
            settled_reduction([row(0)], [row(100)])


if __name__ == '__main__':
    unittest.main()
