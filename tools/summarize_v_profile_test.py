import unittest

from summarize_v_profile import parse_profile, summarize


class VProfileSummaryTests(unittest.TestCase):
    def test_real_v_units_and_non_profile_output(self):
        rows = parse_profile('Saved screenshot: document.png\n'
                             '  150 6684.276ms 6683.985ms 44561840ns main__draw_corner \n'
                             ' 84683331 1029.994ms 1029.994ms 12ns builtin__array__get\n')
        self.assertEqual(rows[0], dict(function='main__draw_corner', calls=150,
            inclusive_ms=6684.276, self_ms=6683.985, average_inclusive_ns=44561840.0))
        self.assertEqual(rows[1]['calls'], 84683331)

    def test_rankings_keep_inclusive_self_and_calls_separate(self):
        rows = parse_profile('1 200.0ms 5.0ms 200000000ns outer\n'
                             '50 100.0ms 80.0ms 2000000ns inner\n'
                             '100 1.0ms 1.0ms 10000ns frequent\n')
        result = summarize(rows, 1)
        self.assertEqual(result['inclusive'][0]['function'], 'outer')
        self.assertEqual(result['self'][0]['function'], 'inner')
        self.assertEqual(result['calls'][0]['function'], 'frequent')

    def test_duplicate_process_reports_cannot_be_combined_silently(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            parse_profile('1 1ms 1ms 1000000ns main\n2 2ms 2ms 1000000ns main\n')

    def test_negative_self_time_is_retained_as_a_diagnostic(self):
        result = summarize(parse_profile('1 1ms -0.1ms 1000000ns nested\n'))
        self.assertEqual(result['negative_self_rows'][0]['self_ms'], -0.1)

    def test_zero_duration_rows_are_valid(self):
        row = parse_profile('1 0.000ms 0.000ms 63ns main__tiny\n')[0]
        self.assertEqual(row['average_inclusive_ns'], 63)

    def test_truncated_and_nonfinite_rows_are_rejected(self):
        for text in ['1 2ms 1ms 3ns\n', '1 nanms 1ms 3ns bad\n']:
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, 'Malformed'):
                parse_profile(text)

    def test_invalid_counters_and_empty_files_are_rejected(self):
        for text in ['', 'browser failed\n', '0 1ms 1ms 1ns zero\n',
                     '1 -1ms 1ms 1ns negative\n', '1 1ms 1ms -1ns negative\n']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_profile(text)

    def test_limit_must_be_positive(self):
        with self.assertRaises(ValueError):
            summarize([], 0)


if __name__ == '__main__':
    unittest.main()
