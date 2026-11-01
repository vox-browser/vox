import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

from run_memory_bounded import job_processes, publish_adopted_processes, read_adopted_processes, stop_job


class BoundedCommandTests(unittest.TestCase):
    def test_exited_group_permission_error_preserves_child_exit(self):
        process = Mock(pid=10)
        process.poll.return_value = 1
        with patch('run_memory_bounded.process_snapshot', return_value={}), \
             patch('run_memory_bounded.os.killpg', side_effect=PermissionError):
            stop_job(process, {10: 'original'})
        process.wait.assert_called_once_with()

    def test_group_permission_error_still_rejects_active_owned_processes(self):
        for child_exit, snapshot in [(None, {}), (1, {11: (1, 11, 100, 'owned')})]:
            process = Mock(pid=10)
            process.poll.return_value = child_exit
            with patch('run_memory_bounded.process_snapshot', return_value=snapshot), \
                 patch('run_memory_bounded.os.kill'), \
                 patch('run_memory_bounded.os.killpg', side_effect=PermissionError):
                with self.assertRaises(PermissionError):
                    stop_job(process, {11: 'owned'})
            process.wait.assert_not_called()

    def test_exited_group_does_not_target_a_reused_pid(self):
        process = Mock(pid=10)
        process.poll.return_value = 0
        with patch('run_memory_bounded.process_snapshot', return_value={11: (1, 11, 100, 'reused')}), \
             patch('run_memory_bounded.os.kill') as kill, \
             patch('run_memory_bounded.os.killpg', side_effect=PermissionError):
            stop_job(process, {11: 'original'})
        kill.assert_not_called()
        process.wait.assert_called_once_with()

    def test_adopted_roots_require_the_exact_start_and_retain_children(self):
        snapshot = {10: (1, 10, 100, 'a'), 20: (1, 20, 200, 'b'),
                    21: (20, 21, 300, 'c'), 30: (1, 30, 400, 'reused')}
        owned = job_processes(snapshot, 10, {}, {20: 'b', 30: 'old', 40: 'gone'})
        self.assertEqual(owned, {10: 'a', 20: 'b', 21: 'c'})
        snapshot.pop(20)
        snapshot[21] = (1, 21, 300, 'c')
        self.assertEqual(job_processes(snapshot, 10, owned), {10: 'a', 21: 'c'})

    def test_registry_rejects_invalid_or_incomplete_identities(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'registry.json'
            self.assertEqual(read_adopted_processes(path), {})
            for value in [{}, [dict(pid=1, started='x')], [dict(pid=True, started='x')],
                          [dict(pid=10, started='')], [dict(pid=10)], [dict(pid='10', started='x')]]:
                path.write_text(json.dumps(value))
                with self.assertRaises(ValueError):
                    read_adopted_processes(path)

    def test_real_reparented_job_is_included_in_the_memory_budget(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            external = subprocess.Popen([sys.executable, '-c',
                'import time; time.sleep(1); x=bytearray(80*1024*1024); time.sleep(30)'],
                start_new_session=True)
            try:
                registry = root / 'pids.json'
                publish_adopted_processes(registry, [external.pid])
                self.assertIn(external.pid, read_adopted_processes(registry))
                result = subprocess.run([sys.executable, str(Path(__file__).with_name('run_memory_bounded.py')),
                    '--limit-gib', '.0625', '--timeout', '10', '--lock', str(root / 'lock'),
                    '--report', str(root / 'report.json'), '--adopt-pids-from', str(registry),
                    '--', sys.executable, '-c', 'import time; time.sleep(30)'],
                    capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode, 125, result.stderr)
                report = json.loads((root / 'report.json').read_text())
                self.assertEqual(report['reason'], 'memory_limit')
                self.assertIn(str(external.pid), report['adopted_processes'])
                self.assertGreater(report['observed_peak_rss_bytes'], report['limit_bytes'])
                self.assertEqual(external.wait(timeout=5), -9)
            finally:
                if external.poll() is None:
                    external.kill()
                    external.wait()

    def test_tracks_compiler_children_and_detached_children_without_other_jobs(self):
        snapshot = {10: (1, 10, 100, 'a'), 11: (10, 10, 200, 'b'),
                    12: (11, 12, 400, 'c'), 20: (1, 20, 800, 'd')}
        owned = job_processes(snapshot, 10, {})
        self.assertEqual(owned, {10: 'a', 11: 'b', 12: 'c'})
        snapshot.pop(10)
        snapshot[12] = (1, 12, 400, 'c')
        self.assertEqual(job_processes(snapshot, 10, owned), {11: 'b', 12: 'c'})
        snapshot[12] = (1, 12, 1, 'recycled')
        self.assertEqual(job_processes(snapshot, 10, owned), {11: 'b'})

    def test_real_child_memory_is_bounded_and_concurrent_job_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            helper = Path(__file__).with_name('run_memory_bounded.py')
            base = [sys.executable, str(helper), '--lock', str(root / 'lock')]
            marker = root / 'started'
            code = ("import pathlib,time; pathlib.Path(" + repr(str(marker))
                    + ").touch(); time.sleep(2); x=bytearray(80*1024*1024); time.sleep(30)")
            child = 'import subprocess,sys; subprocess.run([sys.executable,"-c",' + repr(code) + '])'
            with (root / 'log').open('w') as log:
                first = subprocess.Popen(base + ['--limit-gib', '.0625', '--timeout', '10',
                    '--report', str(root / 'first.json'), '--', sys.executable, '-c', child],
                    stdout=log, stderr=log)
                try:
                    deadline = time.monotonic() + 5
                    while not marker.exists() and time.monotonic() < deadline:
                        time.sleep(.02)
                    self.assertTrue(marker.exists())
                    second = subprocess.run(base + ['--report', str(root / 'second.json'),
                        '--', sys.executable, '-c', 'raise Exception("must not launch")'],
                        stdout=log, stderr=log, timeout=5)
                    self.assertEqual(second.returncode, 125)
                    self.assertEqual(json.loads((root / 'second.json').read_text())['reason'], 'busy')
                    self.assertEqual(first.wait(timeout=12), 125)
                    result = json.loads((root / 'first.json').read_text())
                    self.assertEqual(result['reason'], 'memory_limit')
                    self.assertGreater(result['observed_peak_rss_bytes'], result['limit_bytes'])
                    third = subprocess.run(base + ['--report', str(root / 'third.json'),
                        '--', sys.executable, '-c', 'raise SystemExit(7)'],
                        stdout=log, stderr=log, timeout=5)
                    self.assertEqual(third.returncode, 7)
                    timed = subprocess.run(base + ['--timeout', '.2', '--report',
                        str(root / 'timeout.json'), '--', sys.executable, '-c',
                        'import time; time.sleep(30)'], stdout=log, stderr=log, timeout=5)
                    self.assertEqual(timed.returncode, 125)
                    self.assertEqual(json.loads((root / 'timeout.json').read_text())['reason'], 'timeout')
                finally:
                    if first.poll() is None:
                        first.kill()
                        first.wait()


if __name__ == '__main__':
    unittest.main()
