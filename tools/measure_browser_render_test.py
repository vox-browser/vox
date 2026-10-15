#!/usr/bin/env python3
"""Check first-frame attribution and comparable-input guards without a browser."""

import copy
import unittest

from measure_browser_render import native_summary, scripting_summary, summarize


def sample(variant, milliseconds, instructions):
    return {
        "variant": variant,
        "cache_sha256": "same-initial-cache",
        "binary_sha256": "one-binary",
        "library_sha256": "one-library",
        "timings_ms": {"navigation_to_first_document_paint": milliseconds},
        "native": {"scopes": {"navigation_to_first_document_paint": [instructions]}},
        "scripting": None,
    }


class RenderMeasurementTests(unittest.TestCase):
    def test_refresh_does_not_replace_first_document_timing_or_policy(self):
        log = "\n".join([
            "Ladybird V timing: run_javascript 201 ms",
            "Ladybird V scripting: enabled=true runtime=true sources=4 source_bytes=30000 preloaded_scripts=2",
            "Ladybird V timing: navigation_to_first_document_paint 901 ms",
            "Ladybird V timing: run_javascript 299 ms",
            "Ladybird V scripting: enabled=false runtime=false sources=0 source_bytes=0 preloaded_scripts=0",
            "Ladybird V timing: navigation_to_first_document_paint 1901 ms",
        ])
        self.assertEqual(native_summary(log), {
            "run_javascript": 201, "navigation_to_first_document_paint": 901})
        self.assertEqual(scripting_summary(log), {
            "enabled": True, "runtime": True, "sources": 4,
            "source_bytes": 30000, "preloaded_scripts": 2})

    def test_medians_use_native_times_and_first_instruction_scope(self):
        rows = [sample("before", 1200, 500), sample("after", 800, 300),
                sample("before", 1000, 550), sample("after", 600, 310)]
        rows[0]["native"]["scopes"]["navigation_to_first_document_paint"].append(9999)
        result = summarize(rows)
        self.assertEqual(result["variants"]["before"]["median_ms"][
            "navigation_to_first_document_paint"], 1100)
        self.assertEqual(result["variants"]["before"]["median_instruction_scopes"][
            "navigation_to_first_document_paint"], 525)
        self.assertAlmostEqual(result["first_document_frame_speedup"], 1100 / 700)

    def test_changed_cache_or_per_variant_binary_is_rejected(self):
        original = [sample("before", 1000, 500), sample("after", 600, 300),
                    sample("before", 1001, 501), sample("after", 601, 301)]
        for key in ("cache_sha256", "binary_sha256", "library_sha256"):
            with self.subTest(key=key):
                rows = copy.deepcopy(original)
                rows[2][key] = "changed"
                with self.assertRaises(RuntimeError):
                    summarize(rows)

    def test_unavailable_instructions_do_not_invent_cpu_counts(self):
        rows = [sample("before", 1000, 500), sample("after", 600, 300)]
        for row in rows:
            row["native"]["scopes"] = {}
        result = summarize(rows)
        self.assertEqual(result["variants"]["before"]["median_instruction_scopes"], {})
        self.assertIsNone(scripting_summary("older binary has no scripting diagnostics"))


if __name__ == "__main__":
    unittest.main()
