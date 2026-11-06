import json
import unittest

from summarize_load_stages import summarize
from summarize_thread_load_stages import summarize_main_thread


def fixture():
    return ('Vox instruction stage begin: 123 1 10 browser_main\n'
            'Vox thread instruction stage begin: 123 1 5 browser_main\n'
            'Vox instruction stage begin: 123 2 20 child\n'
            'Vox thread instruction stage begin: 123 2 10 child\n'
            'Vox thread instruction stage end: 123 2 30\n'
            'Vox instruction stage end: 123 2 80\n'
            'Vox thread instructions cumulative: capture_document_encoded 60\n'
            'Vox coalition instructions: ' + json.dumps(dict(
                label='capture_document_encoded', coalition_id=1, instructions=110,
                tasks_started=3, tasks_exited=1)) + '\n'
            'Vox instructions cumulative: capture_document_encoded 100\n')


class ThreadLoadStageTests(unittest.TestCase):
    def test_thread_and_process_streams_reconcile_independently(self):
        text = fixture()
        main, process = summarize_main_thread(text), summarize(text)
        rows = {r['stage']: r for r in main['rows']}
        self.assertEqual(main['main_thread_instructions'], 60)
        self.assertNotIn('process_instructions', main)
        self.assertEqual(rows['child']['exclusive'], 20)
        self.assertEqual(rows['browser_main']['exclusive'], 35)
        self.assertEqual(rows['unscoped_main_thread']['exclusive'], 5)
        self.assertEqual(rows['other_threads_helpers_and_endpoint_skew']['exclusive'], 50)
        self.assertEqual(sum(r['exclusive'] for r in main['rows']), 110)
        self.assertEqual(process['process_instructions'], 100)
        self.assertEqual(next(r['exclusive'] for r in process['rows'] if r['stage'] == 'child'), 60)

    def test_process_endpoint_cannot_substitute_for_a_missing_thread_endpoint(self):
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            summarize_main_thread(fixture().replace(
                'Vox thread instructions cumulative: capture_document_encoded 60\n', ''))

    def test_missing_thread_stages_cannot_be_reported_as_zero_cost(self):
        text = '\n'.join(x for x in fixture().splitlines()
                         if not x.startswith('Vox thread instruction stage '))
        with self.assertRaises(ValueError):
            summarize_main_thread(text)

    def test_unavailable_thread_endpoint_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unavailable'):
            summarize_main_thread(fixture() + 'Vox thread instructions unavailable: encoded error=45\n')

    def test_unavailable_thread_stage_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unavailable'):
            summarize_main_thread(fixture().replace(
                'Vox thread instruction stage end: 123 2 30',
                'Vox thread instruction stage unavailable: 123 2 error=45'))

    def test_malformed_regressing_or_crossing_thread_records_are_rejected(self):
        for old, new in [
            ('end: 123 2 30', 'end: 123 2 invalid'),
            ('end: 123 2 30', 'end: 123 2 9'),
            ('end: 123 2 30', 'end: 123 1 30'),
        ]:
            with self.subTest(new=new), self.assertRaises(ValueError):
                summarize_main_thread(fixture().replace(
                    'Vox thread instruction stage ' + old,
                    'Vox thread instruction stage ' + new))


if __name__ == '__main__':
    unittest.main()
