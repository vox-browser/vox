import unittest
import hashlib
import json
from pathlib import Path
import tempfile

from ladybird_native_cohort import assess, catalog_ids, expectation_names
from wpt_expectation_errata import load_expectation_errata


class CohortTests(unittest.TestCase):
    def test_catalog_retains_order_and_query_variants(self):
        self.assertEqual(catalog_ids('# revision\na\na?x=1\nb\n'), ['a', 'a?x=1', 'b'])
        for source in ['', '# comment\n', 'a\na\n']:
            with self.assertRaises(ValueError):
                catalog_ids(source)

    def test_expected_names_preserve_multiline_source_descriptions(self):
        source = 'Harness status: OK\n\nFound 2 tests\n\nPass\tselector {\n  color: red\n}\nFail\tother\n'
        self.assertEqual(expectation_names(source), ['selector {\n  color: red\n}', 'other'])
        with self.assertRaises(ValueError):
            expectation_names('Found 2 tests\nPass\tonly one\n')

    def test_missing_registration_does_not_pass_with_clean_reported_results(self):
        payload = dict(harness=0, tests=[dict(name='first', status=0)])
        row = assess(payload, ['first', 'second'], 0)
        self.assertFalse(row['all_pass'])
        self.assertEqual(row['missing_names'], ['second'])
        self.assertFalse(assess(None, ['first'], 0)['all_pass'])

    def test_harness_failures_process_failures_and_failed_assertions_remain_failures(self):
        payload = dict(harness=0, tests=[dict(name='one', status=0)])
        self.assertTrue(assess(payload, ['one'], 0)['all_pass'])
        self.assertFalse(assess(payload, ['one'], 1)['all_pass'])
        payload['harness'] = 2
        self.assertFalse(assess(payload, ['one'], 0)['all_pass'])
        payload['harness'], payload['tests'][0]['status'] = 0, 1
        self.assertFalse(assess(payload, ['one'], 0)['all_pass'])

    def test_duplicate_expected_names_and_additional_runtime_tests_are_accounted_for(self):
        payload = dict(harness=0, tests=[dict(name='one', status=0)])
        self.assertFalse(assess(payload, ['one', 'one'], 0)['all_pass'])
        payload['tests'].append(dict(name='newly registered', status=0))
        self.assertTrue(assess(payload, ['one'], 0)['all_pass'])
        payload['tests'][1]['status'] = 1
        self.assertFalse(assess(payload, ['one'], 0)['all_pass'])


class ExpectationErrataTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.page = self.root / 'test.html'
        self.original = b'test({\n  expected: "50px"\n}, "unchanged test name");\n'
        self.page.write_bytes(self.original)
        self.manifest = self.root / 'errata.json'
        self.data = dict(format='vox-wpt-expectation-errata-v1', ladybird_revision='pinned',
            corrections=[dict(case='test', source_sha256=hashlib.sha256(self.original).hexdigest(),
                original_assertion='  expected: "50px"', corrected_assertion='  expected: "250px"',
                reason='Documented numeric accumulation correction')])

    def load(self):
        self.manifest.write_text(json.dumps(self.data))
        return load_expectation_errata(self.manifest, self.root, 'pinned',
                                      [dict(id='test', url='/test.html')])

    def test_served_correction_preserves_exported_bytes_and_records_both_hashes(self):
        overrides, applied = self.load()
        served = overrides['/test.html'][0]
        self.assertEqual(self.page.read_bytes(), self.original)
        self.assertEqual(served, self.original.replace(b'50px', b'250px'))
        self.assertEqual(applied[0]['source_sha256'], hashlib.sha256(self.original).hexdigest())
        self.assertEqual(applied[0]['served_sha256'], hashlib.sha256(served).hexdigest())

    def test_changed_revision_or_source_fails_closed(self):
        self.data['ladybird_revision'] = 'different'
        with self.assertRaises(ValueError):
            self.load()
        self.data['ladybird_revision'] = 'pinned'
        self.page.write_bytes(self.original + b'changed')
        with self.assertRaises(ValueError):
            self.load()

    def test_harness_control_flow_changes_and_duplicate_corrections_are_rejected(self):
        correction = self.data['corrections'][0]
        for value in ['  expected: "250px"; done()', '  expected: "</script>"',
                      'setup({timeout: 99999})', '  expected: "250px"\n// injected']:
            correction['corrected_assertion'] = value
            with self.assertRaises(ValueError):
                self.load()
        correction['corrected_assertion'] = '  expected: "250px"'
        self.data['corrections'].append(dict(correction))
        with self.assertRaises(ValueError):
            self.load()

    def test_missing_or_ambiguous_assertion_and_unselected_case_are_rejected(self):
        correction = self.data['corrections'][0]
        correction['original_assertion'] = '  expected: "missing"'
        with self.assertRaises(ValueError):
            self.load()
        correction['original_assertion'] = '  expected: "50px"'
        self.original += self.original
        self.page.write_bytes(self.original)
        correction['source_sha256'] = hashlib.sha256(self.original).hexdigest()
        with self.assertRaises(ValueError):
            self.load()
        correction['case'] = 'not-selected'
        with self.assertRaises(ValueError):
            self.load()


if __name__ == '__main__':
    unittest.main()
