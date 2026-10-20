import unittest

from pikabu_browser_memory import clean_environment, comparison, native_readiness


class ComparisonTests(unittest.TestCase):
    def row(self, value):
        return {'memory': {'settled_physical_footprint_bytes': value}}

    def test_overlapping_trial_ranges_do_not_pass_on_a_lower_median(self):
        self.assertFalse(comparison([self.row(100), self.row(210)],
                                    [self.row(200), self.row(220)])['target_met'])
        self.assertFalse(comparison([self.row(200)], [self.row(200)])['target_met'])
        self.assertTrue(comparison([self.row(100), self.row(150)],
                                   [self.row(200), self.row(220)])['target_met'])

    def test_native_endpoint_rejects_blank_and_unpainted_windows(self):
        painted = 'Ladybird V timing: first_paint_replay (2000 commands) 10 ms\n'
        installed = 'Ladybird V timing: install_total 100 ms\n'
        for log in ['', painted, installed, installed * 2]:
            with self.assertRaises(RuntimeError):
                native_readiness(log)
        self.assertEqual(native_readiness(installed * 2 + painted)['completed_installs'], 2)
        self.assertEqual(native_readiness(installed + painted)['completed_installs'], 1)

    def test_ambient_local_proxies_cannot_bypass_the_offline_guard(self):
        inherited = {key: 'http://127.0.0.1:7890' for key in
                     ['HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy', 'VOX_PROXY']}
        self.assertFalse(set(inherited) & set(clean_environment(inherited)))


if __name__ == '__main__':
    unittest.main()
