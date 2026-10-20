import unittest

from pikabu_browser_memory import comparison, native_readiness


class ComparisonTests(unittest.TestCase):
    def row(self, value):
        return {'memory': {'settled_physical_footprint_bytes': value}}

    def test_overlapping_trial_ranges_do_not_pass_on_a_lower_median(self):
        self.assertFalse(comparison([self.row(100), self.row(210)],
                                    [self.row(200), self.row(220)])['target_met'])
        self.assertFalse(comparison([self.row(200)], [self.row(200)])['target_met'])
        self.assertTrue(comparison([self.row(100), self.row(150)],
                                   [self.row(200), self.row(220)])['target_met'])

    def test_native_endpoint_rejects_blank_and_partially_loaded_windows(self):
        painted = 'Ladybird V timing: first_paint_replay (2000 commands) 10 ms\n'
        installed = 'Ladybird V timing: install_total 100 ms\n'
        for log in ['', painted, installed + painted, installed * 2]:
            with self.assertRaises(RuntimeError):
                native_readiness(log)
        self.assertEqual(native_readiness(installed * 2 + painted)['completed_installs'], 2)


if __name__ == '__main__':
    unittest.main()
