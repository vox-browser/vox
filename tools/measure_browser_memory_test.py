#!/usr/bin/env python3
"""Check first-document attribution and physical-memory window selection."""

import unittest

from measure_browser_memory import observe_installations, summarize_memory


def reading(seconds, footprint=100, resident=150):
    return {"observed_seconds": seconds, "physical_footprint_bytes": footprint,
            "resident_size_bytes": resident, "lifetime_max_physical_footprint_bytes": 200,
            "exited": False}


class BrowserMemoryTests(unittest.TestCase):
    def test_capture_allocation_spike_does_not_enter_steady_window(self):
        rows = [reading(i / 10) for i in range(81)] + [reading(8.5, 1000, 1200)]
        result = summarize_memory(rows, 3, 9, 1500)
        self.assertEqual(result["first_frame_observation"]["observed_seconds"], .3)
        self.assertEqual(result["preceding_first_frame_observation"]["observed_seconds"], .2)
        self.assertEqual(result["steady_physical_footprint_bytes"], 100)
        self.assertEqual(result["steady_physical_footprint_range_percent"], 0)
        self.assertEqual(result["lifetime_peak_physical_footprint_bytes"], 1000)
        self.assertEqual(result["kernel_peak_rss_bytes"], 1500)

    def test_refresh_changes_retention_scope_without_replacing_first_frame(self):
        log = "Ladybird V timing: parse_document 10 ms\nLadybird V timing: document_install_to_first_paint 300 ms\n"
        events = []
        observe_installations(log, .3, events)
        observe_installations(log, .4, events)
        log += "Ladybird V timing: parse_document 15 ms\nLadybird V timing: document_install_to_first_paint 350 ms\n"
        observe_installations(log, 2, events)
        self.assertEqual(len(events), 4)
        self.assertEqual([event["installation"] for event in events], [1, 1, 2, 2])
        rows = [reading(i / 10, 100 if i < 20 else 300) for i in range(81)]
        result = summarize_memory(rows, 3, 9, 500, events)
        self.assertEqual(result["first_frame_observation"]["physical_footprint_bytes"], 100)
        self.assertEqual(result["steady_physical_footprint_bytes"], 300)
        self.assertIn("later document replacement", result["retention_scope"])
        self.assertEqual(result["pre_replacement_plateau"]["physical_footprint_bytes"], 100)

    def test_missing_frame_or_steady_samples_is_rejected(self):
        for index in [None, 0]:
            with self.subTest(index=index), self.assertRaises(RuntimeError):
                summarize_memory([reading(0), reading(.1)], index, 9, 500)
        with self.assertRaises(RuntimeError):
            summarize_memory([reading(0), reading(.1)], 1, 9, 500)


if __name__ == "__main__":
    unittest.main()
