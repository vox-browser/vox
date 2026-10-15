import ctypes
import threading
import time
import unittest
from types import SimpleNamespace

from compare_browser_memory import ForegroundControl, summarize_samples, TreeMemory
from process_instruction_counts import RusageInfoV4


class BrowserMemoryComparisonTests(unittest.TestCase):
    def test_foreground_monitor_reacquires_only_during_scheduled_polls(self):
        calls = []
        def inspect(pid):
            calls.append(pid)
            return {'pid': pid, 'was_active': len(calls) > 1, 'active': True}
        control = ForegroundControl(123, True, start_at=1, inspect=inspect)
        for elapsed in [0, .5, 1, 1.5, 2, 3, 4, 5]:
            control.poll(elapsed)
        self.assertEqual(calls, [123] * 5)
        self.assertEqual(control.verify_steady(5), [3, 5])
        self.assertEqual(control.activation_at(4)['seconds'], 4)

    def test_rejects_focus_loss_even_when_activation_succeeds_before_capture(self):
        control = ForegroundControl(123, True)
        control.checks = [{'seconds': t, 'active': True, 'was_active': t != 4}
                          for t in range(6)]
        with self.assertRaisesRegex(RuntimeError, 'lost foreground focus'):
            control.verify_steady(5)
        # Earlier recovery is permitted after a complete stable window.
        control.checks += [{'seconds': t, 'active': True, 'was_active': True}
                           for t in range(6, 9)]
        self.assertEqual(control.verify_steady(8), [6, 8])

    def test_rejects_uncovered_foreground_windows_and_supports_background_diagnostics(self):
        control = ForegroundControl(123, True)
        control.checks = [{'seconds': 0, 'active': True, 'was_active': True}]
        with self.assertRaisesRegex(RuntimeError, 'Insufficient foreground checks'):
            control.verify_steady(5)
        background = ForegroundControl(123, False, inspect=lambda _: self.fail('unexpected activation'))
        background.poll(5, force=True)
        self.assertIsNone(background.verify_steady(5))
        self.assertIsNone(background.activation_at(5))

    def test_samples_all_live_descendants_once_and_sums_current_footprints(self):
        def read(pid, flavor, pointer):
            usage = ctypes.cast(pointer, ctypes.POINTER(RusageInfoV4)).contents
            usage.ri_phys_footprint = {1: 100, 2: 200, 3: 300}[pid]
            usage.ri_lifetime_max_phys_footprint = 9999
            usage.ri_proc_start_abstime = pid * 1000
            return 0

        counter = TreeMemory.__new__(TreeMemory)
        counter.root, counter.started = 1, time.monotonic()
        counter.samples, counter.lock = [], threading.Lock()
        counter.api = SimpleNamespace(lib=SimpleNamespace(proc_pid_rusage=read),
                                      path=lambda pid: f'process-{pid}',
                                      children=lambda pid: {1: [2, 3], 2: [3], 3: []}[pid])
        counter.sample()
        self.assertEqual(counter.samples[0]['bytes'], 600)
        self.assertEqual({p['pid'] for p in counter.samples[0]['processes']}, {1, 2, 3})

    def test_uses_simultaneous_tree_total_and_excludes_later_capture_spike(self):
        samples = [{'seconds': i / 10, 'bytes': 300 + i,
                    'processes': [{'pid': 1, 'bytes': 100}, {'pid': 2, 'bytes': 200 + i}]}
                   for i in range(31)]
        samples.append({'seconds': 3.1, 'bytes': 9999, 'processes': [{'pid': 1}]})
        result = summarize_samples(samples, 3)
        self.assertEqual(result['steady_bytes'], 325)
        self.assertEqual(result['peak_simultaneous_bytes'], 330)
        self.assertEqual(len(result['processes_at_endpoint']), 2)

    def test_rejects_missing_live_settled_window(self):
        with self.assertRaises(RuntimeError):
            summarize_samples([{'seconds': 2, 'bytes': 0, 'processes': []}], 2)


if __name__ == '__main__':
    unittest.main()
