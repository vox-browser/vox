import ctypes
import errno
import os
from pathlib import Path
import subprocess
import sys
import time
import tempfile
import unittest

from measure_browser_instructions import fresh_vox_cache, parse_native_counters
from process_instruction_counts import MacCounters, ProcessTreeCounter, Reading, RusageInfoV4


class FakeCounters:
    def __init__(self):
        self.readings = {1: Reading(1, 100, False, 1000, 2000),
                         2: Reading(2, 200, False, 300, 400)}
        self.child_map = {1: [2]}

    def read(self, pid):
        if pid not in self.readings:
            raise OSError(errno.ESRCH, "exited")
        return self.readings[pid]

    def children(self, pid):
        return self.child_map.get(pid, [])

    def path(self, pid):
        return f"process-{pid}"


class CounterAccountingTests(unittest.TestCase):
    def test_cache_snapshot_is_fresh_for_each_run_and_does_not_modify_template(self):
        with tempfile.TemporaryDirectory() as directory:
            template = Path(directory) / "template"
            (template / "pages").mkdir(parents=True)
            source = template / "pages" / "document"
            source.write_bytes(b"original page")
            with fresh_vox_cache(template) as (cache, first_hash):
                snapshot = cache
                (cache / "pages" / "document").write_bytes(b"network refresh")
            self.assertFalse(snapshot.exists())
            self.assertEqual(source.read_bytes(), b"original page")
            with fresh_vox_cache(template) as (cache, second_hash):
                self.assertEqual((cache / "pages" / "document").read_bytes(), b"original page")
                self.assertEqual(first_hash, second_hash)
            source.write_bytes(b"new template")
            with fresh_vox_cache(template) as (_, changed_hash):
                self.assertNotEqual(first_hash, changed_hash)

    def test_cache_snapshot_cleanup_also_runs_after_capture_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "capture failed"):
                with fresh_vox_cache(Path(directory)) as (cache, _):
                    snapshot = cache
                    raise RuntimeError("capture failed")
            self.assertFalse(snapshot.exists())

    def test_rusage_v4_abi_matches_the_public_macos_structure(self):
        self.assertEqual(ctypes.sizeof(RusageInfoV4), 296)
        self.assertEqual(RusageInfoV4.ri_instructions.offset, 248)

    def test_descendants_are_included_and_exited_counts_are_retained(self):
        api = FakeCounters()
        counter = ProcessTreeCounter(api, 1)
        baseline = counter.sample()
        api.readings[1] = Reading(1, 100, False, 2000, 3000)
        api.readings[2] = Reading(2, 200, True, 800, 900)
        api.child_map.clear()
        self.assertEqual(counter.report(baseline)["instructions"], 1500)
        del api.readings[2]
        report = counter.report(baseline)
        self.assertEqual(report["instructions"], 1500)
        self.assertEqual(report["root_instructions"], 1000)
        self.assertTrue(report["aggregate_is_lower_bound"])
        self.assertEqual(report["missing_final_sample_count"], 0)
        self.assertFalse(report["processes"][1]["missing_final_sample"])

    def test_reused_pid_does_not_charge_unrelated_work(self):
        api = FakeCounters()
        counter = ProcessTreeCounter(api, 1)
        counter.sample()
        api.child_map.clear()
        api.readings[2] = Reading(2, 999, False, 9000000, 10000000)
        report = counter.report()
        self.assertEqual(report["instructions"], 1300)
        self.assertTrue(report["processes"][1]["missing_final_sample"])
        self.assertEqual(report["missing_final_sample_count"], 1)

    def test_disappearing_child_is_reported_as_a_lower_bound(self):
        api = FakeCounters()
        counter = ProcessTreeCounter(api, 1)
        counter.sample()
        api.child_map.clear()
        del api.readings[2]
        report = counter.report()
        self.assertEqual(report["instructions"], 1300)
        self.assertTrue(report["processes"][1]["missing_final_sample"])

    def test_new_child_after_navigation_is_counted_from_its_start(self):
        api = FakeCounters()
        counter = ProcessTreeCounter(api, 1)
        baseline = counter.sample()
        api.readings[3] = Reading(3, 300, False, 700, 900)
        api.child_map[1].append(3)
        self.assertEqual(counter.report(baseline)["instructions"], 700)

    def test_native_scope_totals_do_not_enter_adjacent_phase_deltas(self):
        report = parse_native_counters("""
Vox instructions cumulative: startup 100
Vox instructions cumulative: parse_document 160
Vox instructions scope: install_total 250
Vox instructions cumulative: install_styles 300
Vox instructions scope: install_total 125
""")
        self.assertEqual([p["instructions"] for p in report["phases"]], [100, 60, 140])
        self.assertEqual(report["scopes"], {"install_total": [250, 125]})


@unittest.skipUnless(sys.platform == "darwin", "requires macOS hardware counters")
class NativeCounterTests(unittest.TestCase):
    def test_live_process_counters_advance(self):
        api = MacCounters()
        first = api.read(os.getpid())
        second = api.read(os.getpid())
        self.assertGreater(second.instructions, first.instructions)
        self.assertEqual(first.identity, second.identity)

    def test_exit_counters_can_be_read_before_wait_reaps_the_child(self):
        api = MacCounters()
        process = subprocess.Popen(["/usr/bin/true"])
        try:
            deadline = time.monotonic() + 5
            while True:
                reading = api.read(process.pid)
                if reading.exited:
                    break
                self.assertLess(time.monotonic(), deadline)
                time.sleep(.01)
            self.assertGreater(reading.instructions, 0)
            self.assertEqual(process.wait(), 0)
            with self.assertRaises(OSError):
                api.read(process.pid)
        finally:
            if process.returncode is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    unittest.main()
