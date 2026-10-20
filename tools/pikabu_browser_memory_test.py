import unittest

from pikabu_browser_memory import clean_environment, comparison, native_readiness, validate_native_document


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
        with self.assertRaises(RuntimeError):
            native_readiness(installed + painted + installed + 'Ladybird V timing: first_paint_replay (0 commands) 1 ms\n')

    def test_native_endpoint_rejects_navigation_away_from_a_previously_painted_page(self):
        document = dict(url='https://pikabu.ru/', ready='complete', title='Pikabu',
                        paint_commands=600, selections=[dict(name='stories', count=15)])
        validate_native_document(document)
        for change in [dict(url='about:blank'), dict(ready='loading'), dict(title=''),
                       dict(paint_commands=0), dict(selections=[])]:
            with self.assertRaises(RuntimeError):
                validate_native_document(document | change)

    def test_ambient_local_proxies_cannot_bypass_the_offline_guard(self):
        inherited = {key: 'http://127.0.0.1:7890' for key in
                     ['HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy', 'VOX_PROXY']}
        self.assertFalse(set(inherited) & set(clean_environment(inherited)))


if __name__ == '__main__':
    unittest.main()
