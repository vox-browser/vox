import json
from pathlib import Path
import tempfile
import unittest

from summarize_prod_modes import summarize


class ScrollModeSummaryTest(unittest.TestCase):
    def fixture(self, root):
        def write(path, value):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value))
        write(root/'protocol.json', dict(counter_pairs=1, timing_pairs=1, runtime_inputs={'renderer': 'pinned'}))
        write(root/'restoration.json', dict(restored=True, expected='original', actual='original'))
        rows = []
        for mode, count in [('single', 2**60+1), ('parallel', 2**60+100)]:
            for cohort in ('timing', 'counters'):
                name = cohort+'-1-'+mode
                rows.append(dict(name=name, cohort=cohort, mode=mode, pair=1, exit=0, executable_sha256=mode))
                write(root/name/'run.json', dict(valid=True, browser_exit_code=0,
                                                source_and_binary_sha256={'renderer': 'pinned'}))
                data = dict(mean_scroll_fps=60, scroll_interval_us=dict(median=16000,p95=20000,max=30000),
                            fraction_over_budget=.1, update_layer_us=dict(mean=10000),
                            completed_inputs=600,completed_publications=100,moving_intervals=100)
                if cohort == 'counters':
                    data['instruction_measurement'] = dict(instructions=count,wall_ms=1000,samples=dict(
                        start=dict(user_ns=10,system_ns=20),complete=dict(user_ns=24000010,system_ns=20)))
                write(root/name/'summary.json',data)
        write(root/'attempts.json', rows)

    def test_exact_instruction_integers_and_explicit_legacy_cpu_conversion(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            self.fixture(root)
            result=summarize(root,dict(mach_numer=125,mach_denom=3,converted_to_posix_ratio=1))
            self.assertEqual(result['medians']['single']['instructions'],2**60+1)
            self.assertEqual(result['medians']['single']['cpu_ms'],1000)
            self.assertEqual(result['medians']['single']['cpu_ms_per_scroll_publication'],10)
            self.assertEqual(len(result['paired_changes']),1)
            with self.assertRaisesRegex(ValueError,'calibration failed'):
                summarize(root,dict(converted_to_posix_ratio=.024))

    def test_changed_native_identity_and_failed_restoration_reject_summary(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            self.fixture(root)
            path=root/'counters-1-single/run.json'
            data=json.loads(path.read_text())
            data['source_and_binary_sha256']['renderer']='changed'
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError,'input changed'):
                summarize(root)
            (root/'restoration.json').write_text(json.dumps(dict(restored=False,expected='a',actual='b')))
            with self.assertRaisesRegex(ValueError,'not restored'):
                summarize(root)


if __name__ == '__main__':
    unittest.main()
