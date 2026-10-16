import ctypes
from dataclasses import replace
import errno
import os
import sys
import unittest
from unittest.mock import Mock

from coalition_instruction_counts import (
    CoalitionCounter, CoalitionReading, MacCoalitionCounters,
    ResourceUsagePrefix, instruction_delta,
)


class CoalitionAccountingTests(unittest.TestCase):
    def setUp(self):
        self.before = CoalitionReading(42, 1000, 2000, 2, 1, 10, 11)
        self.after = CoalitionReading(42, 5000, 6000, 10, 9, 12, 13)

    def test_dead_tasks_are_kept_and_completed_startup_tasks_cancel(self):
        delta = instruction_delta(self.before, self.after)
        self.assertEqual(delta['instructions'], 4000)
        self.assertEqual(delta['tasks_started'], 8)
        self.assertEqual(delta['tasks_exited'], 8)
        self.assertEqual(self.after.tasks_started - self.after.tasks_exited, 1)

    def test_different_coalitions_and_overlapping_reads_are_rejected(self):
        for after in [replace(self.after, coalition_id=43),
                      replace(self.after, sample_started=10.5),
                      replace(self.after, sample_completed=11.5)]:
            with self.subTest(after=after), self.assertRaises(ValueError):
                instruction_delta(self.before, after)

    def test_every_decreasing_counter_is_rejected(self):
        for name in ['instructions', 'cycles', 'tasks_started', 'tasks_exited']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                instruction_delta(self.before, replace(self.after, **{name: 0}))

    def test_invalid_task_totals_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'task totals'):
            instruction_delta(self.before, replace(self.after, tasks_exited=11))

    def test_boundary_excludes_in_progress_or_late_sample_without_reading_again(self):
        api = Mock()
        api.read.side_effect = [self.before, self.after]
        counter = CoalitionCounter(api, 42)
        counter.sample()
        counter.sample()
        self.assertEqual(counter.snapshot_before(12.5), self.before)
        self.assertEqual(counter.snapshot_before(13), self.after)
        self.assertEqual(api.read.call_count, 2)
        with self.assertRaisesRegex(RuntimeError, 'No retained'):
            counter.snapshot_before(10)

    def test_counter_rejects_changed_group_and_retains_last_good_sample(self):
        api = Mock()
        api.read.side_effect = [self.before, replace(self.after, coalition_id=43)]
        counter = CoalitionCounter(api, 42)
        counter.sample()
        with self.assertRaisesRegex(ValueError, 'changed'):
            counter.sample()
        self.assertEqual(list(counter.snapshots), [self.before])

    def test_missing_reads_propagate_instead_of_becoming_zero(self):
        api = Mock()
        api.read.side_effect = OSError(errno.ESRCH, 'coalition reaped')
        counter = CoalitionCounter(api, 42)
        with self.assertRaises(OSError):
            counter.sample()
        self.assertFalse(counter.snapshots)

    def test_prefix_matches_kernel_abi(self):
        self.assertEqual(ctypes.sizeof(ResourceUsagePrefix), 264)
        self.assertEqual(ResourceUsagePrefix.cpu_time_eqos_len.offset, 184)
        self.assertEqual(ResourceUsagePrefix.cpu_instructions.offset, 248)
        self.assertEqual(ResourceUsagePrefix.cpu_cycles.offset, 256)

    def test_invalid_constructor_arguments_are_rejected(self):
        for cid, history in [(0, 1), (1, 0), (-1, 1)]:
            with self.assertRaises(ValueError):
                CoalitionCounter(Mock(), cid, history)

    def test_short_pidinfo_read_is_not_accepted_as_a_valid_group(self):
        api = object.__new__(MacCoalitionCounters)
        api.pidinfo = Mock(return_value=8)
        with self.assertRaisesRegex(RuntimeError, 'ABI'):
            api.resource_coalition(123)

    def test_kernel_read_failure_retains_errno(self):
        api = object.__new__(MacCoalitionCounters)

        def missing(*args):
            ctypes.set_errno(errno.ESRCH)
            return -1

        api.usage = missing
        with self.assertRaises(OSError) as failure:
            api.read(42)
        self.assertEqual(failure.exception.errno, errno.ESRCH)

    def test_unsupported_kernel_layout_or_absent_instructions_is_rejected(self):
        api = object.__new__(MacCoalitionCounters)
        for qos, instructions in [(6, 100), (7, 0)]:
            def read(cid, pointer, size):
                prefix = ctypes.cast(pointer, ctypes.POINTER(ResourceUsagePrefix)).contents
                prefix.cpu_time_eqos_len = qos
                prefix.cpu_instructions = instructions
                return 0

            api.usage = read
            with self.subTest(qos=qos, instructions=instructions), self.assertRaises(RuntimeError):
                api.read(42)


@unittest.skipUnless(sys.platform == 'darwin', 'requires macOS hardware counters')
class NativeCoalitionTests(unittest.TestCase):
    def test_read_only_self_counter_advances(self):
        api = MacCoalitionCounters()
        cid = api.resource_coalition(os.getpid())
        before = api.read(cid)
        checksum = sum(i * i for i in range(10000))
        after = api.read(cid)
        self.assertGreater(checksum, 0)
        self.assertGreater(instruction_delta(before, after)['instructions'], 0)
        self.assertEqual(cid, api.resource_coalition(os.getpid()))
        # The inherited test coalition can contain unrelated tasks. This tests
        # the read ABI, not exclusivity, complete browser coverage or parity.


if __name__ == '__main__':
    unittest.main()
