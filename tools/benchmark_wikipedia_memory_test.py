import unittest
from unittest.mock import patch

from benchmark_wikipedia_memory import allocator_from_symbols, summarize, verify_allocators


def row(variant, settled, peak=500_000_000, image='same', cache='frozen'):
    return dict(variant=variant, cache_digest=cache, raw_viewport_sha256=image,
        memory=dict(settled_physical_footprint_bytes=settled,
                    settled_range_bytes=[settled, settled],
                    observed_simultaneous_peak_bytes=peak))


class WikipediaMemoryTargetTests(unittest.TestCase):
    def test_distinguishes_os_memory_from_the_browsers_allocator(self):
        self.assertEqual(allocator_from_symbols('000100 T _prealloc_scope_begin\n'), 'prealloc')
        self.assertEqual(allocator_from_symbols('000100 T _GC_malloc\n'), 'boehm')
        for symbols in ('', '000100 T _platform__new_arena\n',
                        '000100 T _prealloc_scope_begin\n000200 T _GC_malloc\n'):
            with self.assertRaises(ValueError):
                allocator_from_symbols(symbols)

    @patch('benchmark_wikipedia_memory.subprocess.check_output')
    def test_rejects_the_wrong_allocator_before_launching_browsers(self, symbols):
        symbols.side_effect = ['000100 T _prealloc_scope_begin\n', '000100 T _GC_malloc\n']
        with self.assertRaisesRegex(ValueError, 'Require prealloc in both'):
            verify_allocators('before', 'after', 'prealloc')
        symbols.side_effect = ['000100 T _prealloc_scope_begin\n'] * 2
        self.assertEqual(verify_allocators('before', 'after', 'prealloc'),
                         {'before': 'prealloc', 'after': 'prealloc'})

    def test_checks_every_run_in_decimal_mb_and_reports_peaks_separately(self):
        rows = [row('before', 120_000_000), row('after', 99_000_000),
                row('before', 130_000_000), row('after', 100_000_001)]
        result = summarize(rows, 100_000_000)
        self.assertLess(result['after']['median_settled_bytes'], 100_000_000)
        self.assertFalse(result['passed'])
        rows[-1] = row('after', 100_000_000)
        result = summarize(rows, 100_000_000)
        self.assertTrue(result['passed'])
        self.assertEqual(result['after']['observed_launch_peak_bytes'], [500_000_000] * 2)

    def test_rejects_a_settled_spike_even_when_every_run_median_passes(self):
        rows = [row('before', 120_000_000), row('after', 99_000_000)]
        rows[-1]['memory']['settled_range_bytes'] = [98_000_000, 100_000_001]
        self.assertFalse(summarize(rows, 100_000_000)['passed'])

    def test_rejects_rendering_changes_and_mismatched_workloads(self):
        result = summarize([row('before', 120), row('after', 90, image='changed')], 100)
        self.assertFalse(result['passed'])
        with self.assertRaises(ValueError):
            summarize([row('before', 120), row('after', 90, cache='changed')], 100)
        with self.assertRaises(ValueError):
            summarize([row('before', 120)], 100)


if __name__ == '__main__':
    unittest.main()
