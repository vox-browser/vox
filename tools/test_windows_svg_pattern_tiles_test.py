import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from test_linux_browser import smoke_environment
from test_windows_svg_pattern_tiles import run_guarded_capture


class GuardedCaptureTest(unittest.TestCase):
    def test_capture_keeps_private_state_and_guard_receipt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "capture.log"
            browser = ["Vox.exe", "--window-width=800", "http://127.0.0.1:8000/"]
            environment = smoke_environment(root, {})

            def run(command, *, env, log_path, timeout):
                self.assertEqual(command[:3], ["guard.exe", "240000", "3072"])
                self.assertEqual(command[5:], browser)
                self.assertEqual(env["APPDATA"], str(root / "config"))
                self.assertEqual(env["LOCALAPPDATA"], str(root / "xdg-cache"))
                self.assertEqual(env["TEMP"], environment["TMPDIR"])
                self.assertGreater(timeout, 240)
                Path(command[3]).write_text("window started", encoding="utf-8")
                Path(command[4]).write_text("VOX_SVG_GROUP cache=hit start=2", encoding="utf-8")
                report = '{"child_exit_code":0,"timed_out":false}'
                log_path.write_text(report, encoding="utf-8")
                return report

            with patch("test_windows_svg_pattern_tiles.run", side_effect=run):
                output = run_guarded_capture(Path("guard.exe"), browser, environment, log)
            self.assertEqual(output, "window started\nVOX_SVG_GROUP cache=hit start=2")
            self.assertEqual(log.read_text(encoding="utf-8"), output)
            self.assertTrue(log.with_suffix(".guard.json").is_file())

    def test_failed_guard_leaves_only_current_browser_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "capture.log"
            log.with_suffix(".stdout").write_text("prior run", encoding="utf-8")
            environment = smoke_environment(root, {})

            def run(command, **_):
                Path(command[4]).write_text("window failed", encoding="utf-8")
                raise subprocess.TimeoutExpired(command, 260)

            with patch("test_windows_svg_pattern_tiles.run", side_effect=run):
                with self.assertRaises(subprocess.TimeoutExpired):
                    run_guarded_capture(Path("guard.exe"), ["Vox.exe"], environment, log)
            self.assertEqual(log.read_text(encoding="utf-8"), "window failed")


if __name__ == "__main__":
    unittest.main()
