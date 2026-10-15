import unittest

from measure_browser_scroll import compare, summarize


def frame(number, before, after, total=10):
    return (f"Vox scroll frame: {number} wheel_us=2 prepare_us=3 replay_us=5 "
            f"total_us={total} instructions=100 before_y={before} after_y={after} commands=12\n")


class ScrollMeasurementTests(unittest.TestCase):
    def test_keeps_slow_frames_and_reports_boundary_events_separately(self):
        result = summarize(frame(0, 0, 42) + frame(1, 42, 84, 1000) + frame(2, 84, 84), 3)
        self.assertEqual(result["all"]["frames"], 3)
        self.assertEqual(result["all"]["total_us"]["max"], 1000)
        self.assertEqual(result["moving"]["frames"], 2)
        self.assertEqual(result["moving"]["total_us"]["sum"], 1010)
        self.assertEqual(result["all"]["instructions"]["sum"], 300)

    def test_rejects_incomplete_or_duplicated_frames(self):
        for log in (frame(0, 0, 42), frame(0, 0, 42) * 2,
                    frame(1, 0, 42) + frame(0, 42, 84)):
            with self.assertRaises(ValueError):
                summarize(log, 2)

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
