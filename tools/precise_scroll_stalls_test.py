"""Exercise bounded slow-frame snapshots against a real nested main-thread stack."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == 'darwin', 'Requires Mach main-thread snapshots')
class StallSamplerTests(unittest.TestCase):
    def test_real_stack_symbols_nested_scope_identity_and_idle_exclusion(self):
        with tempfile.TemporaryDirectory(prefix='precise-stall-test-', dir=ROOT / 'Build') as directory:
            directory = Path(directory)
            binary = directory / 'test'
            def run(name, command, limit):
                result = subprocess.run([sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                    '--lock', str(directory / (name + '.lock')),
                    '--report', str(directory / (name + '.json')), '--limit-gib', str(limit),
                    '--', *command], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                return result.stderr
            run('compile', ['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-fobjc-arc',
                '-fno-omit-frame-pointer', '-Wl,-export_dynamic',
                str(ROOT / 'tools/native_precise_scroll_stalls_test.m'),
                '-framework', 'Cocoa', '-framework', 'QuartzCore', '-o', str(binary)], 12)
            log = run('runtime', [str(binary)], 3)
            diagnostic = re.search(r'SCROLL_STALL_DIAGNOSTIC .*samples=(\d+) frames=(\d+) dropped=0 failures=0', log)
            self.assertIsNotNone(diagnostic, log)
            self.assertGreater(int(diagnostic[1]), 0)
            self.assertEqual(int(diagnostic[2]), 2)
            frames = {int(m[1]): (float(m[2]), float(m[3])) for m in re.finditer(
                r'SCROLL_STALL_FRAME id=(\d+) start_us=([\d.]+) end_us=([\d.]+)', log)}
            sampled = set()
            for m in re.finditer(r'SCROLL_STALL_SAMPLE \d+ frame=(\d+) t_us=([\d.]+)', log):
                identity, timestamp = int(m[1]), float(m[2])
                sampled.add(identity)
                start, end = frames[identity]
                self.assertGreaterEqual(timestamp, start + 10000 - 1)
                self.assertLessEqual(timestamp, end)
                if identity == 1:
                    self.assertFalse(frames[2][0] <= timestamp <= frames[2][1])
            self.assertEqual(sampled, {1, 2})
            symbol = re.search(r'SCROLL_STALL_SYMBOL pc=(\w+) base=(\w+) path_hex=(\w+) name_hex='
                              + b'precise_scroll_known_slow_work'.hex(), log)
            self.assertIsNotNone(symbol, log)
            self.assertGreater(int(symbol[1], 16), int(symbol[2], 16))
            self.assertEqual(os.fsdecode(bytes.fromhex(symbol[3])), str(binary))
            self.assertNotIn('SCROLL_STALL_GAP_SAMPLE ', log)

            gap_log = run('runtime-gaps', [str(binary), '--gaps'], 3)
            diagnostic = re.search(r'SCROLL_STALL_DIAGNOSTIC .*samples=(\d+) frames=0 dropped=0 failures=0', gap_log)
            self.assertIsNotNone(diagnostic, gap_log)
            self.assertGreater(int(diagnostic[1]), 0)
            spans = {int(m[1]): (float(m[2]), float(m[3])) for m in re.finditer(
                r'STALL_TEST_GAP inputs=(\d+) start_us=([\d.]+) end_us=([\d.]+)', gap_log)}
            sampled = set()
            for m in re.finditer(r'SCROLL_STALL_GAP_SAMPLE \d+ inputs=(\d+) t_us=([\d.]+)', gap_log):
                identity, timestamp = int(m[1]), float(m[2])
                sampled.add(identity)
                start, end = spans[identity]
                self.assertGreaterEqual(timestamp, start + 10000 - 1)
                self.assertLessEqual(timestamp, end)
            self.assertEqual(sampled, {7, 8})
            self.assertNotIn('SCROLL_STALL_SAMPLE ', gap_log)
            self.assertIn(b'precise_scroll_known_gap_work'.hex(), gap_log)


if __name__ == '__main__':
    unittest.main()
