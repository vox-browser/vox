import unittest

from browser_memory_observer import summarize_peak


class BrowserMemoryObserverTests(unittest.TestCase):
    def samples(self):
        return [dict(seconds=i / 50, physical_footprint_bytes=a + b, processes=[
            dict(pid=1, start_ticks=10, physical_footprint_bytes=a),
            dict(pid=2, start_ticks=20, physical_footprint_bytes=b)])
            for i, (a, b) in enumerate([(100, 1), (50, 100), (40, 20), (35, 10), (20, 10)])]

    def test_peak_is_simultaneous_sum_not_sum_of_independent_maxima(self):
        result = summarize_peak(self.samples(), 1, 10)
        self.assertEqual(result['observed_peak_bytes'], 150)
        self.assertEqual(result['peak_sample']['seconds'], .02)
        self.assertEqual(result['sample_count'], 5)

    def test_missing_samples_changed_root_or_inconsistent_sum_fail(self):
        with self.assertRaisesRegex(RuntimeError, 'Insufficient'):
            summarize_peak(self.samples()[:4], 1, 10)
        with self.assertRaisesRegex(RuntimeError, 'identity'):
            summarize_peak(self.samples(), 1, 11)
        rows = self.samples()
        rows[0]['physical_footprint_bytes'] = 999
        with self.assertRaisesRegex(RuntimeError, 'simultaneous'):
            summarize_peak(rows, 1, 10)


if __name__ == '__main__':
    unittest.main()
