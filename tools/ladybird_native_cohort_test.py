import unittest

from ladybird_native_cohort import assess, catalog_ids, expectation_names


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


if __name__ == '__main__':
    unittest.main()
