import json
import unittest

from summarize_load_stages import legacy_intervals, summarize


def boundary(process=100, coalition=110):
    return ('Vox coalition instructions: ' + json.dumps(dict(
        label='capture_document_encoded', coalition_id=1, instructions=coalition,
        tasks_started=3, tasks_exited=1)) + '\n'
        + f'Vox instructions cumulative: capture_document_encoded {process}\n')


class LoadStageTests(unittest.TestCase):
    def test_nested_exclusive_counts_reconcile_without_adding_inclusive(self):
        text = ('Vox instruction stage begin: 123 1 10 parent\n'
                'Vox instruction stage begin: 123 2 20 child\n'
                'Vox instruction stage end: 123 2 50\n'
                'Vox instruction stage end: 123 1 80\n' + boundary())
        report = summarize(text)
        rows = {r['stage']: r for r in report['rows']}
        self.assertEqual(rows['parent']['exclusive'], 40)
        self.assertEqual(rows['child']['exclusive'], 30)
        self.assertEqual(rows['parent']['inclusive'], 70)
        self.assertEqual(rows['unscoped_process']['exclusive'], 30)
        self.assertEqual(rows['coalition_endpoint_remainder']['exclusive'], 10)
        self.assertEqual(sum(r['exclusive'] for r in report['rows']), 110)

    def test_recursive_same_label_is_aggregated_by_exclusive_work(self):
        report = summarize('Vox instruction stage begin: 123 1 10 recursive\n'
                           'Vox instruction stage begin: 123 2 20 recursive\n'
                           'Vox instruction stage end: 123 2 50\n'
                           'Vox instruction stage end: 123 1 80\n' + boundary())
        row = next(r for r in report['rows'] if r['stage'] == 'recursive')
        self.assertEqual((row['exclusive'], row['inclusive'], row['calls']), (70, 100, 2))

    def test_open_scopes_are_clipped_at_png_not_at_process_exit(self):
        report = summarize('Vox instruction stage begin: 123 1 10 parent\n'
                           'Vox instruction stage begin: 123 2 20 child\n'
                           + boundary() + 'Vox instruction stage end: 123 2 120\n'
                           'Vox instruction stage end: 123 1 130\n')
        rows = {r['stage']: r for r in report['rows']}
        self.assertEqual(rows['child']['exclusive'], 80)
        self.assertEqual(rows['parent']['exclusive'], 10)
        self.assertEqual(rows['child']['partial_calls'], 1)
        self.assertEqual(sum(r['exclusive'] for r in rows.values()), 110)

    def test_disjoint_roots_preserve_unscoped_gaps(self):
        report = summarize('Vox instruction stage begin: 123 1 10 first\n'
                           'Vox instruction stage end: 123 1 20\n'
                           'Vox instruction stage begin: 123 2 40 second\n'
                           'Vox instruction stage end: 123 2 80\n' + boundary())
        self.assertEqual(next(r['exclusive'] for r in report['rows']
                              if r['stage'] == 'unscoped_process'), 50)

    def test_zero_length_stage_is_valid(self):
        report = summarize('Vox instruction stage begin: 123 1 10 empty\n'
                           'Vox instruction stage end: 123 1 10\n' + boundary())
        self.assertEqual(next(r['exclusive'] for r in report['rows'] if r['stage'] == 'empty'), 0)

    def test_other_process_events_cannot_enter_the_browser_budget(self):
        text = ('Vox instruction stage begin: 123 1 10 stage\n'
                'Vox instruction stage begin: 456 1 1 helper\n'
                'Vox instruction stage end: 456 1 5\n'
                'Vox instruction stage end: 123 1 80\n' + boundary())
        report = summarize(text, pid=123)
        self.assertEqual(report['pid'], 123)
        self.assertNotIn('helper', [row['stage'] for row in report['rows']])
        with self.assertRaisesRegex(ValueError, 'explicit PID'):
            summarize(text)

    def test_browser_main_identifies_the_primary_process_when_unique(self):
        report = summarize('Vox instruction stage begin: 123 1 10 browser_main\n'
                           'Vox instruction stage begin: 456 1 1 helper\n'
                           'Vox instruction stage end: 456 1 5\n'
                           'Vox instruction stage end: 123 1 80\n' + boundary())
        self.assertEqual(report['pid'], 123)

    def test_native_capture_phases_exclude_nested_new_work_and_reconcile(self):
        report = summarize('Vox instruction stage begin: 123 1 10 browser_main\n'
                           'Vox instructions cumulative: capture_started 20\n'
                           'Vox instruction stage begin: 123 2 30 child\n'
                           'Vox instruction stage end: 123 2 50\n'
                           'Vox instructions cumulative: capture_cached 60\n'
                           'Vox instructions cumulative: capture_converted 70\n'
                           + boundary())
        rows = {r['stage']: r for r in report['rows']}
        self.assertEqual(rows['browser_main']['exclusive'], 10)
        self.assertEqual(rows['child']['exclusive'], 20)
        self.assertEqual(rows['capture_snapshot']['exclusive'], 20)
        self.assertEqual(rows['capture_conversion']['exclusive'], 10)
        self.assertEqual(rows['png_encoding']['exclusive'], 30)
        self.assertEqual(sum(r['exclusive'] for r in report['rows']), 110)

    def test_capture_inside_existing_scope_is_removed_from_that_scope(self):
        report = summarize('Vox instruction stage begin: 123 1 10 browser_main\n'
                           'Vox instruction stage begin: 123 2 15 replay\n'
                           'Vox instructions cumulative: capture_started 20\n'
                           'Vox instructions cumulative: capture_cached 40\n'
                           'Vox instruction stage end: 123 2 50\n'
                           'Vox instructions cumulative: capture_converted 70\n'
                           + boundary())
        rows = {r['stage']: r for r in report['rows']}
        self.assertEqual(rows['replay']['exclusive'], 5)
        self.assertEqual(rows['capture_snapshot']['exclusive'], 20)
        self.assertEqual(rows['capture_conversion']['exclusive'], 30)
        self.assertEqual(sum(r['exclusive'] for r in report['rows']), 110)

    def test_counter_regression_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Nonmonotonic'):
            summarize('Vox instruction stage begin: 123 1 20 parent\n'
                      'Vox instruction stage end: 123 1 19\n' + boundary())

    def test_wrong_end_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unbalanced'):
            summarize('Vox instruction stage begin: 123 1 10 parent\n'
                      'Vox instruction stage end: 123 2 20\n' + boundary())

    def test_crossing_scopes_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unbalanced'):
            summarize('Vox instruction stage begin: 123 1 10 parent\n'
                      'Vox instruction stage begin: 123 2 20 child\n'
                      'Vox instruction stage end: 123 1 30\n' + boundary())

    def test_reused_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            summarize('Vox instruction stage begin: 123 1 10 first\n'
                      'Vox instruction stage end: 123 1 20\n'
                      'Vox instruction stage begin: 123 1 30 second\n' + boundary())

    def test_zero_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, 'zero'):
            summarize('Vox instruction stage begin: 123 0 10 invalid\n' + boundary())

    def test_unavailable_counter_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unavailable'):
            summarize('Vox instruction stage begin: 123 1 10 parent\n'
                      'Vox instruction stage unavailable: 123 1\n' + boundary())

    def test_malformed_trace_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Malformed'):
            summarize('Vox instruction stage begin: 123 1 invalid\n' + boundary())

    def test_missing_trace_is_not_a_zero_cost_claim(self):
        with self.assertRaisesRegex(ValueError, 'one stage process'):
            summarize(boundary())

    def test_duplicate_endpoint_rejected(self):
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            summarize(boundary() + boundary())

    def test_missing_coalition_endpoint_rejected(self):
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            summarize('Vox instructions cumulative: capture_document_encoded 100\n')

    def test_signed_boundary_remainder_is_not_mislabeled_as_measured_helpers(self):
        report = summarize('Vox instruction stage begin: 123 1 10 stage\n'
                           'Vox instruction stage end: 123 1 80\n' + boundary(100, 99))
        row = next(r for r in report['rows'] if r['stage'] == 'coalition_endpoint_remainder')
        self.assertEqual(row['exclusive'], -1)
        self.assertEqual(sum(r['exclusive'] for r in report['rows']), 99)

    def test_legacy_gaps_ignore_overlapping_scope_totals(self):
        report = legacy_intervals('Vox instructions cumulative: startup 10\n'
                                  'Vox instructions scope: giant_inclusive 99999\n'
                                  'Vox instructions cumulative: parsed 80\n' + boundary())
        self.assertEqual(sum(r['instructions'] for r in report['rows']), 110)
        self.assertEqual(next(r['instructions'] for r in report['rows']
                              if r['checkpoint'] == 'parsed'), 70)

    def test_legacy_counter_regression_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Nonmonotonic'):
            legacy_intervals('Vox instructions cumulative: startup 20\n'
                             'Vox instructions cumulative: parsed 10\n' + boundary())


if __name__ == '__main__':
    unittest.main()
