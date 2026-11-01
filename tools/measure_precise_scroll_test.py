import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import measure_precise_scroll
from measure_precise_scroll import summarize


def log_for(times=None, positions=None):
    times = times or [i * 10000 + 5000 for i in range(12)]
    positions = positions or [i * 8.4 for i in range(12)]
    lines = ["SCROLL_START precise=1 scale=2 input_hz=60 title=fixture"]
    for i in range(12):
        lines.append(f"SCROLL_INPUT {i} t_us={i * 10000} wheel_us=100")
    for i, (time, y) in enumerate(zip(times, positions)):
        lines.append(f"SCROLL_PUBLISH {i} t_us={time} frame_us=1000 "
                     f"input_age_us=1000 inputs={i + 1} scroll_y={y}")
    lines.append("SCROLL_DONE inputs=12 publications=12 duration_us=200000")
    return "\n".join(lines) + "\n"


class PreciseScrollTests(unittest.TestCase):
    def test_launch_isolates_saved_proxy_and_bookmarks_from_user_profile(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            binary = root / "Vox"
            binary.write_bytes(b"fixture binary")
            certificate = root / "replay-ca.pem"
            certificate.write_bytes(b"fixture private trust certificate")
            output = root / "measurement"
            user_profile = root / "user-profile"
            user_profile.mkdir()
            saved = {"settings.json": '{"enabled":true,"host":"saved-proxy","port":"1080"}',
                     "bookmarks.json": '{"visible":true,"items":[],"version":1}'}
            for name, content in saved.items():
                (user_profile / name).write_text(content)

            def compile_probe(command, **kwargs):
                Path(command[-1]).write_bytes(b"fixture probe")

            def launch(command, **kwargs):
                env = kwargs["env"]
                self.assertEqual(Path(env["VOX_PROFILE_DIR"]), output / "profile")
                self.assertEqual(json.loads((output / "profile/settings.json").read_text()),
                                 {"allow_any_site": True})
                bookmarks = json.loads((output / "profile/bookmarks.json").read_text())
                self.assertFalse(bookmarks["visible"])
                self.assertTrue(bookmarks["optimized_defaults_added"])
                self.assertNotIn("--enable-javascript", command)
                self.assertNotIn("--disable-javascript", command)
                self.assertEqual(env["VOX_PROXY"], "http://127.0.0.1:9")
                self.assertEqual(env["SSL_CERT_FILE"], str(certificate))
                self.assertNotIn("VOX_PROFILE_FRAMES", env)
                self.assertEqual(env["VOX_PRECISE_REQUIRED_TITLE"], "fixture")
                kwargs["stdout"].write(log_for())
                return mock.Mock(pid=123, wait=mock.Mock(return_value=0))

            arguments = ["probe", "--binary", str(binary), "--output", str(output),
                         "--inputs", "12", "--network-policy", "fixture offline route",
                         "--require-title", "fixture",
                         "--script-policy", "automatic",
                         "--env", f"VOX_PROFILE_DIR={user_profile}"]
            with mock.patch.object(measure_precise_scroll.sys, "platform", "darwin"), \
                    mock.patch.object(measure_precise_scroll.sys, "argv", arguments), \
                    mock.patch.dict(measure_precise_scroll.os.environ,
                                    VOX_PROFILE_DIR=str(user_profile), VOX_PROFILE_FRAMES="600",
                                    SSL_CERT_FILE=str(certificate),
                                    VOX_PROXY="http://127.0.0.1:9"), \
                    mock.patch.object(measure_precise_scroll.subprocess, "run", compile_probe), \
                    mock.patch.object(measure_precise_scroll.subprocess, "Popen", launch), \
                    mock.patch.object(measure_precise_scroll.os, "cpu_count", return_value=18), \
                    mock.patch.object(measure_precise_scroll.os, "getloadavg",
                                      side_effect=[(1, 2, 3), (4, 5, 6)]), \
                    mock.patch.object(measure_precise_scroll.time, "time", side_effect=[100, 200]), \
                    contextlib.redirect_stdout(io.StringIO()):
                measure_precise_scroll.main()
            evidence = json.loads((output / "run.json").read_text())
            self.assertTrue(evidence["valid"])
            self.assertEqual(evidence["script_policy"], "automatic")
            self.assertEqual(evidence["host"], {"cpu_count": 18,
                             "load_average_before": [1, 2, 3],
                             "load_average_after": [4, 5, 6]})
            self.assertEqual(evidence["started_unix"], 100)
            self.assertEqual(evidence["finished_unix"], 200)
            self.assertEqual(evidence["schedule"]["required_title"], "fixture")
            self.assertEqual(evidence["schedule"]["settle_basis"], "matching document title")
            self.assertEqual(evidence["environment"]["VOX_PROFILE_DIR"], str(output / "profile"))
            self.assertEqual(evidence["environment"]["SSL_CERT_FILE"], str(certificate))
            self.assertEqual(evidence["source_and_binary_sha256"][str(certificate)],
                             hashlib.sha256(certificate.read_bytes()).hexdigest())
            for name, content in saved.items():
                self.assertEqual((user_profile / name).read_text(), content)

    @unittest.skipUnless(sys.platform == "darwin", "macOS injected observer")
    def test_observer_loads_in_helper_without_renderer_or_probe_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            probe = root / "observer.dylib"
            subprocess.run(["clang", "-O2", "-Wall", "-Wextra", "-Werror",
                            "-dynamiclib", "-fobjc-arc",
                            str(Path(measure_precise_scroll.__file__).with_name("measure_precise_scroll_darwin.m")),
                            "-framework", "Cocoa", "-framework", "QuartzCore",
                            "-Wl,-undefined,dynamic_lookup", "-o", str(probe)], check=True)
            source = root / "helper.c"
            source.write_text('int main(void) { return 0; }\n')
            helper = root / "helper"
            subprocess.run(["clang", str(source), "-o", str(helper)], check=True)
            env = {k: v for k, v in os.environ.items() if not k.startswith("VOX_PRECISE_")}
            env["DYLD_INSERT_LIBRARIES"] = str(probe)
            result = subprocess.run([str(helper)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_uses_in_process_publication_timestamps_and_reports_actual_input_rate(self):
        result = summarize(log_for(), 12)
        self.assertEqual(result["mean_publication_fps"], 100)
        self.assertAlmostEqual(result["mean_scroll_fps"], 10 / .11)
        self.assertEqual(result["mean_scroll_interval_fps"], 100)
        self.assertEqual(result["measurement_window_us"], 110000)
        self.assertEqual(result["first_publication_delay_us"], 5000)
        self.assertEqual(result["last_publication_gap_us"], 5000)
        self.assertEqual(result["input_delivery_hz"], 100)  # nominal rate was 60
        self.assertEqual(result["completed_publications"], 12)
        self.assertEqual(result["measured_publications"], 11)
        self.assertEqual(result["fraction_over_budget"], 0)

    def test_keeps_slow_intervals_including_startup_and_reports_deadline_misses(self):
        result = summarize(log_for(times=[1000, 50000, 55000, 60000, 65000, 70000,
                                         75000, 80000, 85000, 95000, 105000, 115000]), 12)
        self.assertEqual(result["scroll_interval_us"]["max"], 49000)
        self.assertEqual(result["intervals_over_budget"], 1)
        self.assertEqual(result["fraction_over_budget"], .1)
        self.assertEqual(result["scroll_interval_us"]["p95"], 49000)

    def test_animated_publications_without_scroll_movement_cannot_inflate_scroll_fps(self):
        result = summarize(log_for(positions=[i // 2 * 8.4 for i in range(12)]), 12)
        self.assertEqual(result["mean_publication_fps"], 100)
        self.assertAlmostEqual(result["mean_scroll_fps"], 5 / .11)
        self.assertEqual(result["mean_scroll_interval_fps"], 50)
        self.assertEqual(result["fraction_over_budget"], 1)

    def test_rejects_navigation_error_even_when_error_content_scrolls(self):
        for title in ("Navigation error", "Navigation error — vox"):
            with self.subTest(title=title), self.assertRaisesRegex(ValueError, "Navigation error page"):
                summarize(log_for().replace("title=fixture", "title=" + title), 12)

    def test_required_document_title_rejects_loading_page_even_when_it_moves(self):
        for title in ("vox", "", "Other page — vox"):
            with self.subTest(title=title), self.assertRaisesRegex(ValueError, "Requested document title"):
                summarize(log_for().replace("title=fixture", "title=" + title), 12,
                          required_title="Пикабу")

    def test_required_title_accepts_loaded_document_with_browser_suffix(self):
        result = summarize(log_for().replace("title=fixture", "title=Горячее | Пикабу — vox"),
                           12, required_title="Пикабу")
        self.assertEqual(result["completed_inputs"], 12)

    def test_average_includes_time_before_first_and_after_last_publication(self):
        result = summarize(log_for(times=[80000 + i * 2000 for i in range(11)] + [115000]), 12)
        self.assertEqual(result["mean_scroll_interval_fps"], 500)
        self.assertAlmostEqual(result["mean_scroll_fps"], 10 / .11)
        self.assertEqual(result["first_publication_delay_us"], 80000)
        self.assertEqual(result["last_publication_gap_us"], 10000)
        self.assertEqual(result["first_counted_scroll_delay_us"], 82000)
        self.assertEqual(result["last_scroll_publication_gap_us"], 10000)

    def test_rejects_publication_that_precedes_its_input(self):
        with self.assertRaisesRegex(ValueError, "precedes"):
            summarize(log_for().replace("t_us=15000 frame_us", "t_us=9000 frame_us"), 12)

    def test_rejects_missing_duplicate_or_out_of_order_samples(self):
        good = log_for()
        for invalid in (good.replace("SCROLL_INPUT 1 ", "SCROLL_INPUT 2 "),
                        good.replace("SCROLL_PUBLISH 1 ", "SCROLL_PUBLISH 2 "),
                        good.replace("SCROLL_PUBLISH 1 ", "IGNORED 1 "),
                        good.replace("SCROLL_DONE", "IGNORED_DONE"),
                        good.replace("inputs=12 publications=12", "inputs=12 publications=11"),
                        good.replace("precise=1", "precise=0"),
                        good + "SCROLL_ERROR native failure\n"):
            with self.subTest(invalid=invalid[-120:]), self.assertRaises(ValueError):
                summarize(invalid, 12)

    def test_rejects_stationary_input_nonfinite_or_reversed_timestamps(self):
        good = log_for()
        for invalid in (log_for(positions=[0] * 12),
                        good.replace("t_us=15000", "t_us=5000"),
                        good.replace("t_us=15000", "t_us=nan"),
                        good.replace("SCROLL_INPUT 0 t_us=0", "SCROLL_INPUT 0 t_us=-1"),
                        good.replace("inputs=3 scroll_y=", "inputs=1 scroll_y="),
                        good.replace("inputs=12 scroll_y=", "inputs=11 scroll_y=")):
            with self.assertRaises(ValueError):
                summarize(invalid, 12)


if __name__ == "__main__":
    unittest.main()
