import unittest

from measure_precise_scroll import summarize


def log_for(times=None, positions=None):
    times = times or [i * 10000 + 5000 for i in range(12)]
    positions = positions or [i * 8.4 for i in range(12)]
    lines = ["SCROLL_START precise=1 scale=2 input_hz=60 title=fixture"]
    for i in range(12):
        lines.append(f"SCROLL_INPUT {i} t_us={i * 10000} wheel_us=100")
    for i, (time, y) in enumerate(zip(times, positions)):
        lines.append(f"SCROLL_PUBLISH {i} t_us={time} frame_us=1000 "
                     f"input_age_us=1000 inputs={i + 1} scroll_y={y}")
    lines.append("SCROLL_DONE inputs=12 publications=12 duration_us=200000")
    return "\n".join(lines) + "\n"


class PreciseScrollTests(unittest.TestCase):
    def test_uses_in_process_publication_timestamps_and_reports_actual_input_rate(self):
        result = summarize(log_for(), 12)
        self.assertEqual(result["mean_publication_fps"], 100)
        self.assertEqual(result["mean_scroll_fps"], 100)
        self.assertEqual(result["input_delivery_hz"], 100)  # nominal rate was 60
        self.assertEqual(result["completed_publications"], 12)
        self.assertEqual(result["measured_publications"], 11)
        self.assertEqual(result["fraction_over_budget"], 0)

    def test_keeps_slow_intervals_including_startup_and_reports_deadline_misses(self):
        result = summarize(log_for(times=[1000, 50000, 55000, 60000, 65000, 70000,
                                         75000, 80000, 85000, 90000, 95000, 115000]), 12)
        self.assertEqual(result["scroll_interval_us"]["max"], 49000)
        self.assertEqual(result["intervals_over_budget"], 1)
        self.assertEqual(result["fraction_over_budget"], .1)
        self.assertEqual(result["scroll_interval_us"]["p95"], 49000)

    def test_animated_publications_without_scroll_movement_cannot_inflate_scroll_fps(self):
        result = summarize(log_for(positions=[i // 2 * 8.4 for i in range(12)]), 12)
        self.assertEqual(result["mean_publication_fps"], 100)
        self.assertEqual(result["mean_scroll_fps"], 50)
        self.assertEqual(result["fraction_over_budget"], 1)

    def test_rejects_missing_duplicate_or_out_of_order_samples(self):
        good = log_for()
        for invalid in (good.replace("SCROLL_INPUT 1 ", "SCROLL_INPUT 2 "),
                        good.replace("SCROLL_PUBLISH 1 ", "SCROLL_PUBLISH 2 "),
                        good.replace("SCROLL_PUBLISH 1 ", "IGNORED 1 "),
                        good.replace("SCROLL_DONE", "IGNORED_DONE"),
                        good.replace("inputs=12 publications=12", "inputs=12 publications=11"),
                        good.replace("precise=1", "precise=0"),
                        good + "SCROLL_ERROR native failure\n"):
            with self.subTest(invalid=invalid[-120:]), self.assertRaises(ValueError):
                summarize(invalid, 12)

    def test_rejects_stationary_input_nonfinite_or_reversed_timestamps(self):
        good = log_for()
        for invalid in (log_for(positions=[0] * 12),
                        good.replace("t_us=15000", "t_us=5000"),
                        good.replace("t_us=15000", "t_us=nan"),
                        good.replace("SCROLL_INPUT 0 t_us=0", "SCROLL_INPUT 0 t_us=-1"),
                        good.replace("inputs=3 scroll_y=", "inputs=1 scroll_y="),
                        good.replace("inputs=12 scroll_y=", "inputs=11 scroll_y=")):
            with self.assertRaises(ValueError):
                summarize(invalid, 12)


if __name__ == "__main__":
    unittest.main()
