import unittest

from measure_load_frames import parse_frames, summarize, summarize_frames


def log(*entries):
    return [(seconds, text) for seconds, text in entries]


class LoadFrameTests(unittest.TestCase):
    def test_frames_are_parsed_with_and_without_quiet_releases(self):
        frames = parse_frames(log(
            (0.40, 'Vox coalition instructions: {}'),
            (0.50, 'VOX_LOAD_RENDER_THROTTLE t_ms=0 cost_ms=180 deferred=0'),
            (0.62, 'VOX_LOAD_RENDER_THROTTLE t_ms=118 cost_ms=40 deferred=3 quiet=1'),
            (0.90, 'VOX_LOAD_RENDER_THROTTLE t_ms=400 cost_ms=25 deferred=5 quiet=2')))
        self.assertEqual([frame['end_ms'] for frame in frames], [0, 118, 400])
        self.assertEqual([frame['cost_ms'] for frame in frames], [180, 40, 25])
        self.assertEqual([frame['quiet_releases'] for frame in frames], [0, 1, 2])
        self.assertAlmostEqual(frames[0]['log_received_ms'], 500)

    def test_a_second_navigation_does_not_extend_the_first_document(self):
        frames = parse_frames(log(
            (0.5, 'VOX_LOAD_RENDER_THROTTLE t_ms=0 cost_ms=180 deferred=0 quiet=0'),
            (0.7, 'VOX_LOAD_RENDER_THROTTLE t_ms=200 cost_ms=30 deferred=1 quiet=1'),
            (2.0, 'VOX_LOAD_RENDER_THROTTLE t_ms=0 cost_ms=90 deferred=0 quiet=0'),
            (2.2, 'VOX_LOAD_RENDER_THROTTLE t_ms=150 cost_ms=30 deferred=1 quiet=1')))
        self.assertEqual([frame['end_ms'] for frame in frames], [0, 200])

    def test_summary_reports_frame_ends_after_the_first_frame(self):
        frames = parse_frames(log(
            (0.5, 'VOX_LOAD_RENDER_THROTTLE t_ms=0 cost_ms=180 deferred=0 quiet=0'),
            (0.62, 'VOX_LOAD_RENDER_THROTTLE t_ms=118 cost_ms=40 deferred=3 quiet=1'),
            (0.9, 'VOX_LOAD_RENDER_THROTTLE t_ms=400 cost_ms=25 deferred=5 quiet=2')))
        # Requests at 300 ms precede the first frame's end at 500 ms.
        result = summarize_frames(frames, [300, 560, 590])
        self.assertEqual(result['first_frame_cost_ms'], 180)
        self.assertAlmostEqual(result['first_frame_end_ms'], 500)
        self.assertEqual(result['second_frame_end_ms'], 118)
        self.assertEqual(result['last_frame_end_ms'], 400)
        self.assertEqual(result['later_frames'], 2)
        self.assertEqual(result['frame_cost_ms'], 245)
        self.assertEqual((result['deferred'], result['quiet_releases']), (5, 2))
        self.assertAlmostEqual(result['last_request_after_first_frame_ms'], 90)

    def test_a_single_frame_and_a_missing_frame_are_distinguished(self):
        only = summarize_frames(parse_frames(log(
            (0.5, 'VOX_LOAD_RENDER_THROTTLE t_ms=0 cost_ms=30 deferred=0'))), [])
        self.assertIsNone(only['second_frame_end_ms'])
        self.assertEqual(only['last_frame_end_ms'], 0)
        self.assertIsNone(only['last_request_after_first_frame_ms'])
        with self.assertRaisesRegex(ValueError, 'no frame'):
            summarize_frames(parse_frames(log((0.5, 'unrelated'))), [])

    def test_cohort_medians_keep_every_trial(self):
        def row(second, last, costs):
            return dict(first_frame_end_ms=500, first_frame_cost_ms=180, second_frame_end_ms=second,
                        last_frame_end_ms=last, later_frames=len(costs), later_frame_cost_ms=costs,
                        frame_cost_ms=180 + sum(costs), main_thread_cpu_ms=300, process_cpu_ms=400,
                        deferred=2, quiet_releases=1, replayed_requests=7)
        result = summarize([row(100, 100, [40]), row(None, 0, []), row(140, 600, [50, 30])])
        self.assertEqual(result['second_frame_end_ms'], 120)
        self.assertEqual(result['second_frame_end_ms_all'], [100, None, 140])
        self.assertEqual(result['last_frame_end_ms'], 100)
        self.assertEqual(result['later_frame_cost_ms'], 40)
        self.assertEqual(result['replayed_requests'], [7])


if __name__ == '__main__':
    unittest.main()
