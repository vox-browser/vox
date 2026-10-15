import unittest

from observed_instruction_delta import observed_instruction_delta
from process_instruction_counts import CounterSnapshot, Reading


def snapshot(at, readings, missing=(), root=(1, 100)):
    values = {reading.identity: reading for reading in readings}
    return CounterSnapshot(at, values, {key: str(key) for key in values},
                           frozenset(missing), {}, root, {})


class ObservedInstructionDeltaTests(unittest.TestCase):
    def test_new_child_starts_at_observed_count_and_later_work_is_excluded(self):
        baseline = snapshot(10, [Reading(1, 100, False, 1000, 2000)])
        middle = snapshot(11, [Reading(2, 200, False, 9000, 12000)])
        endpoint = snapshot(12, [Reading(1, 100, False, 1100, 2200),
                                 Reading(2, 200, True, 9050, 12080)])
        later = snapshot(13, [Reading(2, 200, True, 99999, 99999)])
        result = observed_instruction_delta(baseline, endpoint, [later, middle])
        self.assertEqual(result["instructions"], 150)
        self.assertEqual(result["processes"][1]["baseline_instructions"], 9000)
        self.assertTrue(result["processes"][1]["final_exit_sample"])

    def test_stale_baseline_waits_for_a_fresh_read_and_missing_endpoint_is_omitted(self):
        baseline = snapshot(10, [Reading(1, 100, False, 100, 100),
                                 Reading(2, 200, False, 1, 1)], missing=[(2, 200)])
        fresh = snapshot(11, [Reading(2, 200, False, 10000, 10000)])
        endpoint = snapshot(12, [Reading(1, 100, False, 999, 999),
                                 Reading(2, 200, False, 10040, 10060)], missing=[(1, 100)])
        result = observed_instruction_delta(baseline, endpoint, [fresh])
        self.assertEqual(result["instructions"], 40)
        self.assertEqual(result["omitted_processes"][0]["pid"], 1)
        self.assertEqual(observed_instruction_delta(baseline, endpoint)["instructions"], 0)

    def test_missing_new_task_history_does_not_use_lifetime_zero(self):
        baseline = snapshot(10, [Reading(1, 100, False, 100, 100)])
        endpoint = snapshot(12, [Reading(2, 200, False, 500000, 800000)])
        result = observed_instruction_delta(baseline, endpoint)
        self.assertEqual(result["instructions"], 0)
        self.assertEqual(result["omitted_processes"][0]["reason"], "no fresh baseline reading")

    def test_rejects_changed_root_reversed_boundaries_and_decreasing_counters(self):
        baseline = snapshot(10, [Reading(1, 100, False, 100, 100)])
        with self.assertRaises(ValueError):
            observed_instruction_delta(baseline, snapshot(11, [], root=(1, 101)))
        with self.assertRaises(ValueError):
            observed_instruction_delta(baseline, baseline)
        with self.assertRaises(ValueError):
            observed_instruction_delta(baseline, snapshot(12, []),
                                       [snapshot(11, [], root=(3, 300))])
        with self.assertRaises(RuntimeError):
            observed_instruction_delta(baseline, snapshot(11, [Reading(1, 100, False, 99, 200)]))


if __name__ == "__main__":
    unittest.main()
