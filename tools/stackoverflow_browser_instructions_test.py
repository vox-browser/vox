import copy
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from contextlib import redirect_stdout

import stackoverflow_browser_instructions as bench


def fixture():
    return {"url": bench.URL, "title": "Newest Questions - Stack Overflow",
            "question_ids": ["question-summary-1", "question-summary-2"],
            "required_stylesheets": ["https://stackoverflow.com/main.css"],
            "manifest_sha256": "fixture-hash"}


def audit():
    body = "Question body " * 100
    return {"url": bench.URL, "title": fixture()["title"], "ready": "complete", "fully_active": True,
            "viewport_width": 1024, "viewport_height": 768, "paint_commands": 100,
            "font_set_present": True, "fonts_status": "loaded", "font_faces": [],
            "selections": [
                {"name": "body", "count": 1, "elements": [{"text": body,
                    "text_sha256": hashlib.sha256(body.encode()).hexdigest()}]},
                {"name": "questions", "count": 2, "elements": [
                    {"attributes": {"id": item}} for item in fixture()["question_ids"]]},
                {"name": "images", "count": 0, "elements": []},
                {"name": "all", "count": 20, "elements": []}]}


class FixtureTests(unittest.TestCase):
    def archive(self, directory, html):
        archive = Path(directory)
        (archive / "bodies").mkdir()
        entries = {}
        for url, body, content_type in [(bench.URL, html.encode(), "text/html"),
                                       ("https://stackoverflow.com/main.css", b"body{}", "text/css")]:
            key = hashlib.sha256(body).hexdigest()
            (archive / "bodies" / key).write_bytes(body)
            entries[url] = {"sha256": key, "bytes": len(body), "status": 200,
                            "headers": [{"name": "Content-Type", "value": content_type}]}
        (archive / "manifest.json").write_text(json.dumps({"version": 1, "sealed_unix": 1,
                                                          "url": bench.URL, "responses": entries}))
        return archive

    def test_extracts_original_origin_title_and_ordered_ids_and_authenticates_bodies(self):
        html = '<title>Questions &amp; Answers</title><link rel="stylesheet" href="/main.css">' \
               '<div id="question-summary-2"></div><div id="question-summary-1"></div>'
        with tempfile.TemporaryDirectory() as directory:
            archive = self.archive(directory, html)
            result = bench.fixture_metadata(archive)
            self.assertEqual(result["title"], "Questions & Answers")
            self.assertEqual(result["question_ids"], ["question-summary-2", "question-summary-1"])
            self.assertEqual(result["required_stylesheets"], ["https://stackoverflow.com/main.css"])
            (archive / "bodies" / result["html_sha256"]).write_bytes(b"modified")
            with self.assertRaisesRegex(ValueError, "Archived response changed"):
                bench.fixture_metadata(archive)

    def test_rejects_scripts_duplicate_ids_and_missing_stylesheets(self):
        base = '<title>Questions</title><div id="question-summary-1"></div>'
        for extra in ('<script>run()</script>', '<div id="question-summary-1"></div>',
                      '<link rel="stylesheet" href="/missing.css">'):
            with self.subTest(extra=extra), tempfile.TemporaryDirectory() as directory:
                with self.assertRaises(ValueError):
                    bench.fixture_metadata(self.archive(directory, base + extra))

    def test_only_literal_local_only_font_families_grant_fallback_allowance(self):
        css = '''
        /* @font-face { font-family: Comment; src: local("Ignore me"); } */
        @font-face { font-family: "Adjusted"; src: local("Segoe UI"),local('Arial'); }
        @font-face { font-family: Adjusted; src: local(Segoe UI Bold); font-weight:700; }
        @font-face { font-family: Remote; src: url("remote.woff2"); }
        @font-face { font-family: Mixed; src: local("Segoe UI"), url("remote.woff2"); }
        @font-face { font-family: Duplicate; src: local("Segoe UI"); src:url("remote.woff2"); }
        @font-face { font-family: Shared; src: local("Segoe UI"); }
        @font-face { font-family: Shared; src: url("Segoe UI"); }
        @font-face { font-family: Empty; src: local(""); }
        '''
        self.assertEqual(bench.local_only_font_sources([css]),
                         {"adjusted": ["Arial", "Segoe UI", "Segoe UI Bold"]})


class ContentTests(unittest.TestCase):
    def test_checks_real_count_field_body_hash_and_question_order(self):
        result = bench.validate_document(audit(), fixture())
        self.assertEqual(result["question_ids"], fixture()["question_ids"])
        for mutate in [lambda a: a["selections"][1]["elements"].reverse(),
                       lambda a: a["selections"][1].update(count=3),
                       lambda a: a["selections"][0]["elements"][0].update(text_sha256="wrong"),
                       lambda a: a["selections"].pop(),
                       lambda a: a.update(fonts_status="loading"),
                       lambda a: a.update(title="Challenge")]:
            changed = audit()
            mutate(changed)
            with self.subTest(audit=changed), self.assertRaises(ValueError):
                bench.validate_document(changed, fixture())

    def test_visible_image_must_decode_and_unsettled_or_failed_fonts_are_rejected(self):
        item = {"rect": {"x": 10, "y": 10, "width": 32, "height": 32},
                "attributes": {"src": "/avatar.png"}, "image": {"complete": False}}
        value = audit()
        value["selections"][2].update(count=1, elements=[item])
        with self.assertRaisesRegex(ValueError, "visible image"):
            bench.validate_document(value, fixture())
        item["image"].update(paint_decoded=True, paint_width=32, paint_height=32)
        result = bench.validate_document(value, fixture())
        self.assertEqual(result["required_images"], ["https://stackoverflow.com/avatar.png"])
        item["rect"]["y"] = 900
        item["image"] = {}
        self.assertEqual(bench.validate_document(value, fixture())["required_images"], [])
        for face in [{"family": "Inter", "status": "error"},
                     {"family": "Inter", "status": "loaded", "parsed_font_present": False}]:
            value["font_faces"] = [face]
            with self.assertRaises(ValueError):
                bench.validate_document(value, fixture())

    def test_absent_local_font_fallbacks_need_fixture_provenance_and_remain_in_evidence(self):
        frozen = fixture()
        frozen["local_font_fallback_sources"] = {"adjusted": ["Segoe UI"]}
        value = audit()
        face = {"family": "Adjusted", "status": "error", "style": "auto", "weight": "auto",
                "parsed_font_present": False, "declared_sources": ["Segoe UI"]}
        value["font_faces"] = [face]
        result = bench.validate_document(value, frozen)
        self.assertEqual(result["unavailable_local_font_fallbacks"],
                         [{key: face[key] for key in ("family", "declared_sources", "style", "weight")}])
        self.assertEqual(result["font_faces"][0]["declared_sources"], ["Segoe UI"])
        for sources in ([], ["https://example.test/font.woff2"], ["Segoe UI", "Arial"]):
            face["declared_sources"] = sources
            with self.subTest(sources=sources), self.assertRaisesRegex(ValueError, "did not load"):
                bench.validate_document(value, frozen)
        face.update(declared_sources=["Segoe UI"], status="loading")
        with self.assertRaisesRegex(ValueError, "did not load"):
            bench.validate_document(value, frozen)
        face["status"] = "error"
        with self.assertRaisesRegex(ValueError, "did not load"):
            bench.validate_document(value, fixture())

    def test_replay_requires_main_css_and_visible_images_and_retains_optional_misses(self):
        required = [bench.URL, *fixture()["required_stylesheets"], "https://stackoverflow.com/avatar.png"]
        rows = [{"method": "GET", "url": url, "status": 200, "archived": True} for url in required]
        rows += [{"url": "https://stackoverflow.com/favicon.ico", "status": 404, "archived": False},
                 {"error": "optional closed connection"}]
        doc = {"required_images": [required[-1]]}
        result = bench.classify_replay(rows, fixture(), doc)
        self.assertFalse(result["missing_required_urls"])
        self.assertEqual(len(result["unarchived"]), 1)
        self.assertEqual(len(result["transport_errors"]), 1)
        for absent in required:
            with self.subTest(absent=absent), self.assertRaisesRegex(ValueError, "required document/CSS"):
                bench.classify_replay([r for r in rows if r.get("url") != absent], fixture(), doc)

    def test_clean_environment_replaces_ambient_proxy_gc_and_injection(self):
        with patch.dict(os.environ, {"HTTP_PROXY": "http://wrong", "no_proxy": "*",
                                     "GC_DONT_GC": "1", "LD_PRELOAD": "/wrong.so",
                                     "UNRELATED_SECRET": "private"}, clear=True):
            env = bench.clean_environment({"proxy": "socks5h://127.0.0.1:123", "ca": "/private/ca.pem"})
        for absent in ("HTTP_PROXY", "GC_DONT_GC", "LD_PRELOAD", "UNRELATED_SECRET"):
            self.assertNotIn(absent, env)
        self.assertEqual(env["no_proxy"], "")
        self.assertEqual(env["GC_MARKERS"], "1")
        self.assertEqual(env["GALLIUM_DRIVER"], "llvmpipe")
        self.assertEqual(env["LP_NUM_THREADS"], "1")


class PairTests(unittest.TestCase):
    def pair(self, baseline, candidate, metric="callgrind_guest_instruction_references"):
        return {"baseline": {"instructions": baseline, "instruction_metric": metric},
                "candidate": {"instructions": candidate, "instruction_metric": metric}}

    def test_reports_all_pairs_and_uses_conservative_exact_threshold(self):
        result = bench.pair_statistics([self.pair(1000, 850), self.pair(1010, 840)])
        self.assertTrue(result["target_met"])
        self.assertEqual(result["paired_differences"], [150, 170])
        result = bench.pair_statistics([self.pair(1000, 800), self.pair(1000, 1100)])
        self.assertFalse(result["target_met"])
        self.assertEqual(result["regressing_pairs"], 1)
        self.assertEqual(result["candidate_counts"], [800, 1100])

    def test_rejects_incomplete_pairs_zero_counts_and_mixed_metrics(self):
        mixed = self.pair(1000, 800)
        mixed["candidate"]["instruction_metric"] = "hardware_retired_user_instructions"
        software_mixed = self.pair(1000, 800)
        software_mixed["candidate"]["instruction_metric"] = "cachegrind_guest_instruction_references"
        for pairs in ([], [{"baseline": self.pair(1, 1)["baseline"]}], [self.pair(0, 1)], [mixed], [software_mixed]):
            with self.subTest(pairs=pairs), self.assertRaises(ValueError):
                bench.pair_statistics(pairs)


class OrchestrationTests(unittest.TestCase):
    def execute(self, candidate=True, fail_candidate=False, backend="callgrind"):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            baseline = directory / "baseline"
            baseline.write_bytes(b"baseline")
            candidate_file = directory / "candidate"
            candidate_file.write_bytes(b"candidate")
            args = SimpleNamespace(output=directory / "evidence", archive=directory / "archive",
                                   binary=baseline, candidate=candidate_file if candidate else None,
                                   counter_backend=backend, pairs=2, use_display=False,
                                   timeout=30, valgrind="valgrind", required_reduction=.15)
            fixture_data = fixture()
            process = Mock(pid=987654)
            process.poll.return_value = None
            commands = []
            def pin(path):
                return {"path": str(path), "sha256": bench.digest(path), "dynamic_libraries_sha256": {}}
            def start_replay(command, **kwargs):
                output = Path(command[command.index("--output") + 1])
                output.mkdir()
                (output / "ready.json").write_text(json.dumps({"proxy": "socks5h://127.0.0.1:1",
                    "ca": "/ca", "manifest_sha256": fixture_data["manifest_sha256"], "forwarding": False}))
                return process
            def capture(command, **kwargs):
                commands.append(command)
                prefix = Path(command[command.index("--output") + 1])
                selected = Path(command[command.index("--binary") + 1]).name
                if selected == "candidate" and fail_candidate:
                    kwargs["stdout"].write("forced capture failure\n")
                    return SimpleNamespace(returncode=97)
                report = {"document_audit": audit(), "instructions": 800 if selected == "candidate" else 1000,
                          "instruction_metric": backend + "_guest_instruction_references",
                          "hardware_retired": False, "screenshot": str(prefix) + ".png"}
                Path(str(prefix) + ".run-1.json").write_text(json.dumps(report))
                with (args.output / "replay/requests.jsonl").open("a") as requests:
                    for url in [bench.URL, *fixture_data["required_stylesheets"]]:
                        requests.write(json.dumps({"method": "GET", "url": url, "status": 200, "archived": True}) + "\n")
                return SimpleNamespace(returncode=0)
            with patch.object(bench, "fixture_metadata", return_value=fixture_data), \
                    patch.object(bench, "pin_binary", side_effect=pin), \
                    patch.object(bench.subprocess, "Popen", side_effect=start_replay), \
                    patch.object(bench.subprocess, "run", side_effect=capture), \
                    patch.object(bench.os, "killpg"), redirect_stdout(io.StringIO()):
                code = bench.run(args)
            summary = json.loads((args.output / "summary.json").read_text())
            return code, summary, commands

    def test_alternates_pairs_and_reuses_first_baseline_only_as_pixel_reference(self):
        code, summary, commands = self.execute()
        self.assertEqual(code, 0)
        self.assertEqual([r["variant"] for r in summary["observations"]],
                         ["baseline", "candidate", "candidate", "baseline"])
        self.assertTrue(summary["target_met"])
        self.assertNotIn("--expected-png", commands[0])
        self.assertTrue(all("--expected-png" in command for command in commands[1:]))
        self.assertTrue(all(command[0] == "xvfb-run" for command in commands))
        self.assertTrue(all(command[command.index("--url") + 1] == bench.URL for command in commands))

    def test_explicit_cachegrind_is_forwarded_and_keeps_its_distinct_metric(self):
        code, summary, commands = self.execute(backend="cachegrind")
        self.assertEqual(code, 0)
        self.assertEqual(summary["comparison"]["instruction_metric"], "cachegrind_guest_instruction_references")
        self.assertTrue(all(command[command.index("--counter-backend") + 1] == "cachegrind"
                            for command in commands))

    def test_baseline_only_does_not_enforce_a_reduction(self):
        code, summary, _ = self.execute(candidate=False)
        self.assertEqual(code, 0)
        self.assertTrue(summary["valid"])
        self.assertIsNone(summary["target_met"])
        self.assertEqual(summary["baseline_counts"], [1000, 1000])

    def test_a_failed_candidate_preserves_completed_baseline_without_retry(self):
        code, summary, commands = self.execute(fail_candidate=True)
        self.assertEqual(code, 1)
        self.assertFalse(summary["valid"])
        self.assertEqual(len(commands), 2)
        self.assertEqual(summary["observations"][0]["status"], "valid")
        self.assertEqual(summary["observations"][1]["status"], "invalid")
        self.assertEqual(summary["observations"][1]["driver_exit"], 97)


if __name__ == "__main__":
    unittest.main()
