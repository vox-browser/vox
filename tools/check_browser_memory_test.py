import copy
import unittest

from check_browser_memory import compare


def observation(engine, steady, peak=1000):
    return {'engine': engine, 'url': 'http://127.0.0.1:1234/',
            'metric': 'sum of simultaneous process physical footprints',
            'viewport': [1024, 768], 'settle_seconds': 15, 'native_display_backing_scale': 2,
            'matched_native_raster_scale': True, 'binary_sha256': engine,
            'foreground_controlled': True, 'activation': {'active': True},
            'document': {'focused': True, 'visibility': 'visible', 'url': 'http://127.0.0.1:1234/',
                         'width': 1024, 'height': 768, 'scale': 2},
            'command': ['browser', '--enable-javascript'],
            'memory': {'steady_bytes': steady, 'peak_simultaneous_bytes': peak}}


class MemoryTargetTests(unittest.TestCase):
    def test_exact_boundary_passes_and_current_median_controls_target(self):
        chrome = [observation('chrome', value) for value in [900, 1000, 1100]]
        vox = [observation('vox', value) for value in [700, 800, 900]]
        result = compare(vox, chrome)
        self.assertTrue(result['target_met'])
        self.assertFalse(result['all_vox_runs_below_target_for_all_chrome_runs'])
        vox[1]['memory']['steady_bytes'] = 801
        self.assertFalse(compare(vox, chrome)['target_met'])

    def test_rejects_mismatched_and_instrumented_runs(self):
        mutations = [
            {'url': 'https://different.example/'}, {'viewport': [800, 600]}, {'settle_seconds': 10},
            {'matched_native_raster_scale': False}, {'diagnostic_library': 'probe.dylib'},
            {'collector_overrides': {'GC_FREE_SPACE_DIVISOR': '64'}}, {'command': ['browser']},
            {'runtime_overrides': {'JSC_useJIT': 'false'}},
            {'foreground_controlled': False}, {'activation': {'active': False}},
            {'foreground_checks': [], 'foreground_steady_verified': False},
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                sample = observation('vox', 700)
                sample.update(mutation)
                compare([sample], [observation('chrome', 1000)])

    def test_rejects_mixed_executables_and_missing_cohorts(self):
        first = observation('vox', 700)
        changed = copy.deepcopy(first)
        changed['binary_sha256'] = 'different'
        with self.assertRaises(ValueError):
            compare([first, changed], [observation('chrome', 1000)])
        with self.assertRaises(ValueError):
            compare([], [observation('chrome', 1000)])

    def test_rejects_changing_external_snapshot_payloads(self):
        first, second = observation('vox', 700), observation('vox', 710)
        first['runtime_files'] = {'snapshot_payload': {'sha256': 'first'}}
        second['runtime_files'] = {'snapshot_payload': {'sha256': 'changed'}}
        with self.assertRaises(ValueError):
            compare([first, second], [observation('chrome', 1000)])

    def test_rejects_chrome_that_lost_focus_or_loaded_different_document_conditions(self):
        for mutation in [{'focused': False}, {'visibility': 'hidden'}, {'url': 'about:blank'},
                         {'width': 800}, {'height': 600}, {'scale': 1}]:
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                chrome = observation('chrome', 1000)
                chrome['document'].update(mutation)
                compare([observation('vox', 700)], [chrome])


if __name__ == '__main__':
    unittest.main()
