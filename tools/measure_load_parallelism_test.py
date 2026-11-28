import os
from pathlib import Path
import tempfile
import threading
import time
import unittest

from measure_load_parallelism import (PNG_END_CHUNK, ThreadCounters, median_of, png_complete,
                                      summarize, summarize_samples)

MAIN, WORKER, SHORT = 1, 2, 3


def sample(seconds, process_ms, **threads):
    names = dict(main=MAIN, worker=WORKER, short=SHORT)
    return (seconds, int(process_ms * 1e6),
            {names[name]: (int(cpu_ms * 1e6), '' if name == 'main' else name)
             for name, cpu_ms in threads.items()})


class LoadParallelismTests(unittest.TestCase):
    def test_serial_load_reports_one_busy_core(self):
        samples = [sample(0.00, 0, main=0), sample(0.10, 100, main=100),
                   sample(0.20, 200, main=200)]
        result = summarize_samples(samples, MAIN, 0, 0.2)
        self.assertAlmostEqual(result['wall_ms'], 200)
        self.assertAlmostEqual(result['main_thread_cpu_ms'], 200)
        self.assertAlmostEqual(result['other_threads_cpu_ms'], 0)
        self.assertAlmostEqual(result['main_thread_share'], 1)
        self.assertAlmostEqual(result['average_busy_cores'], 1)
        self.assertAlmostEqual(result['wall_ms_with_two_or_more_busy_threads'], 0)
        self.assertEqual(result['wall_ms_by_busy_thread_count'], {'1': 200.0})

    def test_worker_time_and_overlap_are_separated_from_the_main_thread(self):
        samples = [sample(0.0, 0, main=0, worker=0),
                   sample(0.1, 190, main=100, worker=90),   # both busy
                   sample(0.2, 200, main=110, worker=90),   # idle: 10% of the interval
                   sample(0.3, 290, main=110, worker=180)]  # worker only
        result = summarize_samples(samples, MAIN, 0, 0.3)
        self.assertAlmostEqual(result['main_thread_cpu_ms'], 110)
        self.assertAlmostEqual(result['other_threads_cpu_ms'], 180)
        self.assertAlmostEqual(result['average_busy_cores'], 290 / 300)
        self.assertAlmostEqual(result['wall_ms_with_two_or_more_busy_threads'], 100)
        self.assertEqual({key: round(value) for key, value in
                          result['wall_ms_by_busy_thread_count'].items()},
                         {'0': 100, '1': 100, '2': 100})
        self.assertEqual(result['top_threads_cpu_ms'][0], ['worker', 180.0])

    def test_process_total_keeps_threads_that_exited_between_samples(self):
        # The short thread's last 30 ms were never sampled; rusage still has them.
        samples = [sample(0.0, 0, main=0), sample(0.1, 60, main=40, short=20),
                   sample(0.2, 130, main=80)]
        result = summarize_samples(samples, MAIN, 0, 0.2)
        self.assertAlmostEqual(result['process_cpu_ms'], 130)
        self.assertAlmostEqual(result['main_thread_cpu_ms'], 80)
        self.assertAlmostEqual(result['other_threads_cpu_ms'], 50)
        self.assertIn(['short', 20.0], result['top_threads_cpu_ms'])

    def test_interval_excludes_work_after_its_endpoint(self):
        samples = [sample(0.0, 0, main=0), sample(0.1, 100, main=100),
                   sample(0.5, 500, main=500)]
        result = summarize_samples(samples, MAIN, 0, 0.1)
        self.assertAlmostEqual(result['wall_ms'], 100)
        self.assertAlmostEqual(result['process_cpu_ms'], 100)
        with self.assertRaisesRegex(ValueError, 'Too few'):
            summarize_samples(samples, MAIN, 0.2, 0.3)

    def test_png_is_complete_only_after_its_end_chunk(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'document.png'
            self.assertFalse(png_complete(path))
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + b'partial')
            self.assertFalse(png_complete(path))
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + b'data' + PNG_END_CHUNK)
            self.assertTrue(png_complete(path))

    def test_summary_reports_medians_and_every_wall_time(self):
        def row(wall, main):
            return dict(png_sha256='a', replayed_requests=7 if wall < 300 else 5, launch_to_png=dict(
                wall_ms=wall, process_cpu_ms=main + 10, main_thread_cpu_ms=main,
                other_threads_cpu_ms=10, main_thread_share=main / (main + 10),
                average_busy_cores=1, main_thread_utilization=1,
                wall_ms_with_two_or_more_busy_threads=0))
        rows = [row(300, 90), row(100, 30), row(200, 60)]
        result = summarize(rows)
        self.assertEqual(result['launch_to_png']['wall_ms'], 200)
        self.assertEqual(result['launch_to_png']['main_thread_cpu_ms'], 60)
        self.assertEqual(result['launch_to_png']['wall_ms_all'], [300, 100, 200])
        self.assertEqual(result['png_sha256'], ['a'])
        # A capture that replayed fewer requests stays visible in the summary.
        self.assertEqual(result['replayed_requests'], [5, 7])
        # No trial requested the instrumented first-submission endpoint.
        self.assertIsNone(result['launch_to_first_submission']['wall_ms'])
        self.assertIsNone(median_of(rows, 'launch_to_first_submission', 'wall_ms'))

    @unittest.skipUnless(os.uname().sysname == 'Darwin', 'libproc thread counters are macOS-only')
    def test_live_counters_attribute_a_busy_thread(self):
        counters = ThreadCounters()
        pid = os.getpid()
        stop = threading.Event()

        def spin():
            while not stop.is_set():
                pass

        before_threads, before_total = counters.threads(pid), counters.process_cpu_ns(pid)
        worker = threading.Thread(target=spin)
        worker.start()
        time.sleep(0.2)
        after_threads, after_total = counters.threads(pid), counters.process_cpu_ns(pid)
        stop.set()
        worker.join()
        added = [handle for handle in after_threads if handle not in before_threads]
        self.assertEqual(len(added), 1)
        # Thread times are nanoseconds; the rusage total is converted from ticks.
        self.assertGreater(after_threads[added[0]][0], 50_000_000)
        self.assertLess(after_threads[added[0]][0], 400_000_000)
        self.assertGreater(after_total - before_total, 50_000_000)
        self.assertLess(after_total - before_total, 800_000_000)


if __name__ == '__main__':
    unittest.main()
