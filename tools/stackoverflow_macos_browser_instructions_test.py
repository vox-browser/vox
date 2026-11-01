import os
import subprocess
import sys
import unittest
from unittest.mock import patch

import stackoverflow_macos_browser_instructions as bench


def cohort():
    result = []
    for pair in range(1, 8):
        for engine in (('vox', 'brave') if pair % 2 else ('brave', 'vox')):
            result.append(dict(pair=pair, engine=engine, valid=True,
                pixel_validation=dict(exact=True), content=dict(body_sha256='same body'),
                instructions=100 + pair if engine == 'vox' else 200 + pair))
    return result


class CohortTests(unittest.TestCase):
    def test_primary_statistics_include_every_pair_and_use_exact_integer_gate(self):
        result = bench.summarize(cohort(), 7)
        self.assertEqual(result['results']['vox']['median'], 104)
        self.assertEqual(result['results']['brave']['median'], 204)
        self.assertEqual(result['median_vox_over_brave'], 104 / 204)
        self.assertEqual(result['conservative_observed_vox_over_brave'], 107 / 201)
        self.assertEqual(result['observed_ten_percent_gate']['left'], 1070)
        self.assertEqual(result['observed_ten_percent_gate']['right'], 1809)

    def test_missing_failed_duplicate_or_reordered_observations_cannot_be_excluded(self):
        cases = [cohort()[:-1], cohort()[::-1]]
        for changes in [dict(pair=2), dict(engine='brave'), dict(valid=False),
                        dict(instructions=0), dict(instructions=1.5),
                        dict(pixel_validation=dict(exact=False)),
                        dict(content=dict(body_sha256='different body'))]:
            rows = cohort()
            rows[0].update(changes)
            cases.append(rows)
        for rows in cases:
            with self.subTest(rows=rows[:1]), self.assertRaises(RuntimeError):
                bench.summarize(rows, 7)

    def test_a_large_first_pair_is_retained_and_can_fail_the_gate(self):
        rows = cohort()
        rows[0]['instructions'] = 1000
        result = bench.summarize(rows, 7)
        self.assertFalse(result['observed_ten_percent_gate']['passed'])
        self.assertEqual(result['results']['vox']['maximum'], 1000)


class CounterAndProbeTests(unittest.TestCase):
    def report(self):
        return dict(exit=0, unreadable_pids={}, root_instructions=100,
            aggregate_is_lower_bound=True, instructions=120,
            root_final_exit_sample=True, native_instruction_markers=False,
            processes=[dict(pid=1, start_ticks=1000, instructions=100),
                       dict(pid=2, start_ticks=1001, instructions=20)])

    def test_cohort_requires_normal_exit_exact_sums_and_uninstrumented_vox_endpoint(self):
        bench.validate_counter_report(self.report(), 'vox')
        for changes in [dict(exit=-11), dict(shutdown_forced=True),
                        dict(unreadable_pids={1: 13}), dict(root_instructions=0),
                        dict(aggregate_is_lower_bound=False), dict(instructions=121),
                        dict(root_final_exit_sample=False), dict(native_instruction_markers=True)]:
            with self.subTest(changes=changes), self.assertRaises(RuntimeError):
                bench.validate_counter_report({**self.report(), **changes}, 'vox')
        report = self.report()
        report['processes'][1].update(pid=1, start_ticks=1000)
        with self.assertRaisesRegex(RuntimeError, 'Duplicate task'):
            bench.validate_counter_report(report, 'vox')

    def test_zero_probe_is_valid_only_for_the_exact_root_pid(self):
        log = 'JSC_PROBE pid=42 contexts=0 groups=0 evaluations=0\n'
        self.assertEqual(bench.root_probe(log, 42)['contexts'], 0)
        for bad in ['', log.replace('42', '43'), log + log,
                    log.replace('contexts=0', 'contexts=1')]:
            with self.subTest(log=bad), self.assertRaises(RuntimeError):
                bench.root_probe(bad, 42)

    def test_positive_control_must_initialize_and_execute_jsc(self):
        log = 'JSC_PROBE pid=42 contexts=3 groups=1 evaluations=450\n'
        self.assertEqual(bench.root_probe(log, 42, positive=True)['evaluations'], 450)
        for bad in [log.replace('contexts=3', 'contexts=0'),
                    log.replace('evaluations=450', 'evaluations=0')]:
            with self.assertRaises(RuntimeError):
                bench.root_probe(bad, 42, positive=True)


class ContentAndIsolationTests(unittest.TestCase):
    def report(self):
        return dict(document_audit=dict(url=bench.URL, title='title', ready='complete',
            viewport=[1024, 768], scale=1, questionIds=['question-summary-1'],
            bodyText='question text ' * 100, fontsStatus='loaded', allElements=100,
            imageRects=[dict(src='https://example.com/avatar', complete=True,
                naturalWidth=32, naturalHeight=32, rect=dict(x=1, y=2, width=16, height=16))]))

    def test_semantic_audit_rejects_missing_questions_images_fonts_and_wrong_geometry(self):
        fixture = dict(title='title', question_ids=['question-summary-1'])
        content = bench.chrome_content(self.report(), fixture)
        self.assertEqual(content['required_images'], ['https://example.com/avatar'])
        for changes in [dict(url='about:blank'), dict(ready='loading'), dict(scale=2),
                        dict(viewport=[800, 600]), dict(questionIds=[]), dict(fontsStatus='loading')]:
            report = self.report()
            report['document_audit'].update(changes)
            with self.subTest(changes=changes), self.assertRaises(RuntimeError):
                bench.chrome_content(report, fixture)
        report = self.report()
        report['document_audit']['imageRects'][0]['complete'] = False
        with self.assertRaises(RuntimeError):
            bench.chrome_content(report, fixture)

    def test_cohort_environment_cannot_inherit_diagnostic_or_proxy_controls(self):
        with patch.dict(os.environ, dict(DYLD_INSERT_LIBRARIES='probe.dylib',
                VOX_PROFILE_INSTRUCTIONS='', HTTPS_PROXY='http://ambient', JSC_useJIT='false')):
            previous = dict(os.environ)
            with bench.environment(dict(VOX_TEST_WINDOW='1')):
                for key in ('DYLD_INSERT_LIBRARIES', 'VOX_PROFILE_INSTRUCTIONS', 'HTTPS_PROXY', 'JSC_useJIT'):
                    self.assertNotIn(key, os.environ)
            self.assertEqual(dict(os.environ), previous)

    def test_cli_rejects_fewer_than_seven_pairs_and_nonfinite_settlement(self):
        for options in (['--repeat', '6'], ['--settle-seconds', 'nan'], ['--settle-seconds', 'inf']):
            result = subprocess.run([sys.executable, bench.__file__, '--output', '/unused',
                '--expected-vox', '/unused.png', '--expected-brave', '/unused.png',
                '--diff-tool', '/unused', '--jsc-probe', '/unused', *options],
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('at least seven pairs', result.stderr)


if __name__ == '__main__':
    unittest.main()
