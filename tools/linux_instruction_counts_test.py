import ctypes
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

import linux_instruction_counts as linux


class LinuxPerfEventTests(unittest.TestCase):
    def test_event_attaches_before_exec_and_inherits_without_kernel_or_hypervisor(self):
        captured = {}
        def syscall(number, attr, pid, cpu, group, flags):
            captured.update(number=number.value, attr=ctypes.string_at(attr, 64),
                            pid=pid.value, cpu=cpu.value, group=group.value, flags=flags.value)
            return 51
        fake = Mock()
        fake.syscall.side_effect = syscall
        with patch.object(linux.platform, "system", return_value="Linux"), \
                patch.object(linux.platform, "machine", return_value="x86_64"), \
                patch.object(linux.ctypes, "CDLL", return_value=fake):
            counter = linux.LinuxPerfInstructions(321)
        self.assertEqual(captured["number"], 298)
        self.assertEqual((captured["pid"], captured["cpu"], captured["group"], captured["flags"]),
                         (321, -1, -1, 8))
        self.assertEqual(struct.unpack_from("=IIQ", captured["attr"]), (0, 64, 1))
        self.assertEqual(struct.unpack_from("=Q", captured["attr"], 32)[0], 3)
        self.assertEqual(struct.unpack_from("=Q", captured["attr"], 40)[0],
                         (1 << 0) | (1 << 1) | (1 << 5) | (1 << 6) | (1 << 12))
        with patch.object(linux.os, "close") as close:
            counter.close()
            counter.close()
        close.assert_called_once_with(51)

    def test_pmu_failure_is_explicit_and_does_not_select_a_software_counter(self):
        fake = Mock()
        fake.syscall.return_value = -1
        with patch.object(linux.platform, "system", return_value="Linux"), \
                patch.object(linux.platform, "machine", return_value="x86_64"), \
                patch.object(linux.ctypes, "CDLL", return_value=fake), \
                patch.object(linux.ctypes, "get_errno", return_value=2):
            with self.assertRaisesRegex(linux.CounterUnavailable, "errno=2.*explicitly"):
                linux.LinuxPerfInstructions(321)

    def test_raw_counts_reject_zero_unscheduled_multiplexed_and_partial_reads(self):
        counter = object.__new__(linux.LinuxPerfInstructions)
        counter.fd = 10
        for data in (b"", struct.pack("=QQQ", 0, 10, 10),
                     struct.pack("=QQQ", 50, 0, 0), struct.pack("=QQQ", 50, 10, 5)):
            with self.subTest(data=data), patch.object(linux.os, "read", return_value=data):
                with self.assertRaises(linux.CounterUnavailable):
                    counter.finish()
        with patch.object(linux.os, "read", return_value=struct.pack("=QQQ", 55, 10, 10)):
            report = counter.finish()
        self.assertEqual(report["instructions"], 55)
        self.assertTrue(report["hardware_retired"])
        self.assertIn("user", report["instruction_metric"])


@unittest.skipUnless(sys.platform == "linux" and hasattr(os, "fork"), "Linux process lifecycle")
class LinuxLaunchTests(unittest.TestCase):
    def test_unavailable_counter_never_executes_the_target(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "executed"
            command = [sys.executable, "-c", f"open({str(marker)!r}, 'w').write('bad')"]
            factory = Mock(side_effect=linux.CounterUnavailable("no PMU"))
            with self.assertRaisesRegex(linux.CounterUnavailable, "no PMU"):
                linux.run_perf_command(command, cwd=directory, env=os.environ.copy(),
                                       log_path=Path(directory) / "log", timeout=5,
                                       counter_factory=factory)
            self.assertFalse(marker.exists())

    def test_target_is_gated_until_counter_attaches_and_final_read_precedes_reap(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "attached"
            event_order = []
            counter = Mock()
            def attach(pid):
                marker.write_text(str(pid))
                event_order.append("attach")
                return counter
            def finish():
                event_order.append("finish")
                status = os.waitid(os.P_PID, int(marker.read_text()),
                                   os.WEXITED | os.WNOHANG | os.WNOWAIT)
                self.assertIsNotNone(status)
                return {"instructions": 123}
            counter.finish.side_effect = finish
            command = [sys.executable, "-c",
                       f"from pathlib import Path; assert Path({str(marker)!r}).exists(); print('captured')"]
            with patch.object(linux, "_live_group_members", return_value=[]):
                report = linux.run_perf_command(command, cwd=directory, env=os.environ.copy(),
                                               log_path=Path(directory) / "log", timeout=5,
                                               counter_factory=attach)
            self.assertEqual(event_order, ["attach", "finish"])
            self.assertEqual(report["exit"], 0)
            self.assertTrue(report["root_final_exit_sample"])
            self.assertIsNone(report["root_instructions"])
            self.assertIn("captured", (Path(directory) / "log").read_text())
            counter.close.assert_called_once()
            with self.assertRaises(ChildProcessError):
                os.waitpid(report["pid"], os.WNOHANG)

    def test_nonzero_exit_exec_failure_and_timeout_cannot_produce_counts(self):
        for command, timeout, message in [
                ([sys.executable, "-c", "raise SystemExit(7)"], 5, "failed"),
                (["/does-not-exist/vox"], 5, "failed"),
                ([sys.executable, "-c", "import time; time.sleep(30)"], .02, "watchdog")]:
            with self.subTest(command=command), tempfile.TemporaryDirectory() as directory:
                counter = Mock()
                with self.assertRaisesRegex(RuntimeError, message):
                    linux.run_perf_command(command, cwd=directory, env=os.environ.copy(),
                                           log_path=Path(directory) / "log", timeout=timeout,
                                           counter_factory=lambda pid: counter)
                counter.finish.assert_not_called()
                counter.close.assert_called_once()

    def test_live_children_reject_an_incomplete_endpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            counter = Mock()
            with patch.object(linux, "_live_group_members", return_value=[777]), \
                    self.assertRaisesRegex(RuntimeError, "running children"):
                linux.run_perf_command([sys.executable, "-c", "pass"], cwd=directory,
                                       env=os.environ.copy(), log_path=Path(directory) / "log",
                                       timeout=5, counter_factory=lambda pid: counter)
            counter.finish.assert_not_called()
            counter.close.assert_called_once()


class CallgrindParsingTests(unittest.TestCase):
    def parse(self, text, header="part: 1\ndesc: Trigger: Program termination\n"):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "callgrind.out"
            path.write_text(header + text)
            return linux.parse_callgrind(path, expected_pid=42)

    def test_uses_named_ir_column_and_requires_the_final_total(self):
        text = "pid: 42\nevents: Dr Ir Dw\nsummary: 4 123 5\nfn=work\n1 4 123 5\ntotals: 4 123 5\n"
        self.assertEqual(self.parse(text), 123)
        self.assertEqual(self.parse("pid: 42\nevents: Ir\ntotals: 20\n"), 20)

    def test_rejects_truncated_wrong_pid_zero_ambiguous_and_conflicting_counts(self):
        examples = [
            "pid: 42\nevents: Ir\nsummary: 123\n",
            "pid: 43\nevents: Ir\nsummary: 123\ntotals: 123\n",
            "pid: 42\nevents: Ir\nsummary: 0\ntotals: 0\n",
            "pid: 42\nevents: Ir Ir\nsummary: 1 1\ntotals: 1 1\n",
            "pid: 42\nevents: Ir\nsummary: 123\ntotals: 122\n",
            "pid: 42\nevents: Ir\nsummary: 123\ntotals: 123\ntotals: 123\n",
            "pid: 42\nevents: Dr\nsummary: 123\ntotals: 123\n",
            "pid: 42\nevents: Ir\nsummary: bad\ntotals: bad\n",
        ]
        for text in examples:
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                self.parse(text)

    def test_rejects_partial_dumps_and_later_segments_even_with_consistent_totals(self):
        counts = "pid: 42\nevents: Ir\nsummary: 123\ntotals: 123\n"
        for header in ("", "part: 1\n", "desc: Trigger: Program termination\n",
                       "part: 2\ndesc: Trigger: Program termination\n",
                       "part: 1\ndesc: Trigger: dump manual diagnostic\n",
                       "part: 1\npart: 1\ndesc: Trigger: Program termination\n",
                       "part: 1\ndesc: Trigger: Program termination\ndesc: Trigger: Program termination\n"):
            with self.subTest(header=header), self.assertRaisesRegex(RuntimeError, "complete undumped"):
                self.parse(counts, header)

    def test_missing_instrumentation_program_does_not_fall_back_to_another_metric(self):
        with patch.object(linux.shutil, "which", return_value=None), \
                self.assertRaisesRegex(linux.CounterUnavailable, "explicitly selected"):
            linux.run_callgrind_command(["/bin/true"], cwd="/", env={}, log_path="unused",
                                       timeout=1, prefix="unused")


class CachegrindParsingTests(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cachegrind.out"
            path.write_text(text)
            return linux.parse_cachegrind(path)

    def test_requires_ir_only_final_summary_and_matching_flat_cost_rows(self):
        text = "cmd: /test/vox\nevents: Ir\nfl=source.c\nfn=main\n1 12\n+1 3\n*\n-1 2\nsummary: 17\n"
        self.assertEqual(self.parse(text), 17)

    def test_rejects_missing_ambiguous_truncated_negative_or_conflicting_data(self):
        examples = [
            "events: Ir\n1 17\n",
            "1 17\nsummary: 17\n",
            "events: Ir\nsummary: 17\n",
            "events: Ir\n1 0\nsummary: 0\n",
            "events: Ir Dr\n1 17 2\nsummary: 17 2\n",
            "events: Ir\nevents: Ir\n1 17\nsummary: 17\n",
            "events: Ir\n1 -17\nsummary: 17\n",
            "events: Ir\n1 17 3\nsummary: 17\n",
            "events: Ir\n1 17\nsummary: 18\n",
            "events: Ir\n1 17\nsummary: 17\nsummary: 17\n",
            "events: Ir\n1 17\nsummary: 17\n1 1\n",
            "events: Ir\nunknown data\nsummary: 17\n",
        ]
        for text in examples:
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                self.parse(text)

    def test_unavailable_cachegrind_does_not_fall_back(self):
        with patch.object(linux.shutil, "which", return_value=None), \
                self.assertRaisesRegex(linux.CounterUnavailable, "Cachegrind was explicitly selected"):
            linux.run_cachegrind_command(["/bin/true"], cwd="/", env={}, log_path="unused",
                                        timeout=1, prefix="unused")


@unittest.skipUnless(sys.platform == "linux" and Path("/proc/self/stat").is_file(), "Linux /proc process cleanup")
class CallgrindCleanupTests(unittest.TestCase):
    def test_root_success_or_failure_with_live_children_rejects_and_cleans_the_group(self):
        for tool, root_exit, expected in [(tool, code, error) for tool in ("callgrind", "cachegrind")
                                         for code, error in ((0, "running children"), (7, "failed"))]:
            with self.subTest(tool=tool, root_exit=root_exit), tempfile.TemporaryDirectory() as directory:
                directory = Path(directory)
                stub = directory / "fake-valgrind"
                pid_file = directory / "child.pid"
                stub.write_text(f"#!{sys.executable}\n" +
                    "import os,sys,time\nfrom pathlib import Path\n" +
                    "if '--version' in sys.argv:\n print('test-only fake instrumentation');sys.exit(0)\n" +
                    "child=os.fork()\n" +
                    "if child==0:\n time.sleep(30);os._exit(0)\n" +
                    f"Path({str(pid_file)!r}).write_text(str(child))\n" +
                    f"os._exit({root_exit})\n")
                stub.chmod(0o700)
                with self.assertRaisesRegex(RuntimeError, expected):
                    getattr(linux, f"run_{tool}_command")(["/bin/true"], cwd=directory, env=os.environ.copy(),
                                                         log_path=directory / "log", timeout=5,
                                                         prefix=directory / "run", valgrind=str(stub))
                child = int(pid_file.read_text())
                # A killed orphan can briefly remain as a zombie until its
                # reaper collects it. It must never remain an executing task.
                state_path = Path(f"/proc/{child}/stat")
                deadline = linux.time.monotonic() + 2
                while state_path.exists() and linux.time.monotonic() < deadline:
                    if state_path.read_text().rsplit(")", 1)[1].split()[0] == "Z":
                        break
                    linux.time.sleep(.01)
                if state_path.exists():
                    self.assertEqual(state_path.read_text().rsplit(")", 1)[1].split()[0], "Z")

    def test_cachegrind_selects_only_root_file_and_rejects_failed_or_timed_out_valid_footers(self):
        for mode in ("success", "failure", "timeout"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                directory = Path(directory)
                stub = directory / "fake-cachegrind"
                stub.write_text(f"#!{sys.executable}\n" +
                    "import os,sys,time\nfrom pathlib import Path\n" +
                    "if '--version' in sys.argv:\n print('test-only fake cachegrind');sys.exit(0)\n" +
                    "pattern=next(a.split('=',1)[1] for a in sys.argv if a.startswith('--cachegrind-out-file='))\n" +
                    "Path(pattern.replace('%p',str(os.getpid()))).write_text('events: Ir\\n1 17\\nsummary: 17\\n')\n" +
                    "Path(pattern.replace('%p',str(os.getpid()+1000000))).write_text('events: Ir\\n1 999999\\nsummary: 999999\\n')\n" +
                    ("time.sleep(30)\n" if mode == "timeout" else "") +
                    ("sys.exit(7)\n" if mode == "failure" else ""))
                stub.chmod(0o700)
                kwargs = dict(cwd=directory, env=os.environ.copy(), log_path=directory / "log",
                              timeout=.5 if mode == "timeout" else 5,
                              prefix=directory / "run", valgrind=str(stub))
                if mode == "success":
                    report = linux.run_cachegrind_command(["/bin/true"], **kwargs)
                    self.assertEqual(report["instructions"], 17)
                    self.assertEqual(report["instruction_metric"], "cachegrind_guest_instruction_references")
                    self.assertFalse(report["hardware_retired"])
                    self.assertTrue(report["cachegrind_output"].endswith("." + str(report["pid"])))
                    self.assertIn("--instr-at-start=yes", report["command"])
                    self.assertNotIn("--instr-atstart=yes", report["command"])
                    self.assertNotIn("--separate-threads=no", report["command"])
                    with self.assertRaisesRegex(RuntimeError, "evidence already exists"):
                        linux.run_callgrind_command(["/bin/true"], **kwargs)
                else:
                    with self.assertRaisesRegex(RuntimeError, "watchdog" if mode == "timeout" else "failed"):
                        linux.run_cachegrind_command(["/bin/true"], **kwargs)
                self.assertEqual(len(list(directory.glob("run.cachegrind.*"))), 2)


if __name__ == "__main__":
    unittest.main()
