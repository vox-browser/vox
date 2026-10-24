import unittest
import io
from unittest.mock import patch

from measure_browser_scroll import capture_browser_log, compare, summarize, window_size


def frame(number, before, after, total=10):
    return (f"Vox scroll frame: {number} wheel_us=2 prepare_us=3 replay_us=5 "
            f"total_us={total} instructions=100 before_y={before} after_y={after} commands=12\n")


class ScrollMeasurementTests(unittest.TestCase):
    def test_window_includes_complete_browser_chrome(self):
        self.assertEqual(window_size(1024, 768), [1024, 852])
        self.assertEqual(window_size(800, 600), [800, 684])

    def test_keeps_slow_frames_and_reports_boundary_events_separately(self):
        result = summarize(frame(0, 0, 42) + frame(1, 42, 84, 1000) + frame(2, 84, 84), 3)
        self.assertEqual(result["all"]["frames"], 3)
        self.assertEqual(result["all"]["total_us"]["max"], 1000)
        self.assertEqual(result["moving"]["frames"], 2)
        self.assertEqual(result["moving"]["total_us"]["sum"], 1010)
        self.assertEqual(result["all"]["instructions"]["sum"], 300)

    def test_summarizes_collector_fields_when_frames_report_them(self):
        log = (frame(0, 0, 42).rstrip("\n") + " allocated_kb=512 collections=0 heap_mb=300\n"
               + frame(1, 42, 84).rstrip("\n") + " allocated_kb=1024 collections=1 heap_mb=310\n")
        result = summarize(log, 2)
        self.assertEqual(result["moving"]["allocated_kb"]["sum"], 1536)
        self.assertEqual(result["moving"]["collections"]["sum"], 1)
        self.assertNotIn("allocated_kb", summarize(frame(0, 0, 42), 1)["moving"])

    def test_rejects_incomplete_or_duplicated_frames(self):
        for log in (frame(0, 0, 42), frame(0, 0, 42) * 2,
                    frame(1, 0, 42) + frame(0, 42, 84)):
            with self.assertRaises(ValueError):
                summarize(log, 2)

    def test_native_cadence_includes_stalls_between_completed_frames(self):
        log = "".join(frame(n, n * 42, (n + 1) * 42) for n in range(3))
        receipts = [(0, 5000000), (1, 21000000), (2, 121000000)]
        cadence = summarize(log, 3, receipts=receipts)["native_frame_cadence"]
        self.assertEqual(cadence["intervals"], 2)
        self.assertAlmostEqual(cadence["mean_fps"], 2_000_000 / 116000)
        self.assertEqual(cadence["interval_us"]["max"], 100000)
        self.assertNotIn("native_frame_cadence", summarize(frame(0, 0, 42), 1))
        for invalid in (receipts[:2], [(0, 5), (1, 5), (2, 7)]):
            with self.assertRaises(ValueError):
                summarize(log, 3, receipts=invalid)

    def test_timestamps_only_native_frame_completion_lines(self):
        log = "startup\n" + frame(0, 0, 42) + frame(1, 42, 84)
        output, receipts = io.StringIO(), []
        with patch("measure_browser_scroll.time.monotonic_ns", side_effect=(1, 2, 3)):
            capture_browser_log(io.StringIO(log), output, receipts)
        self.assertEqual(output.getvalue(), log)
        self.assertEqual(receipts, [(0, 2), (1, 3)])

    def test_requires_actual_viewport_scroll(self):
        with self.assertRaises(ValueError):
            summarize(frame(0, 0, 0), 1)

    def test_comparison_requires_the_same_workload(self):
        before = dict(url="https://www.wikipedia.org/", viewport=[1024, 768],
                      raster_mode="interactive", cache_sha256="same",
                      **summarize(frame(0, 0, 42, 20), 1))
        after = {**before, **summarize(frame(0, 0, 42, 10), 1)}
        self.assertEqual(compare(before, after)["moving_callback_reduction_percent"], 50)
        for changed in ({"viewport": [800, 600]}, {"cache_sha256": "different"},
                        {"raster_mode": "screenshot"},
                        {"rows": [{**after["rows"][0], "after_y": 40}]}):
            with self.assertRaises(ValueError):
                compare(before, {**after, **changed})


if __name__ == "__main__":
    unittest.main()
