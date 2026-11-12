"""Focused checks for the Linux integration driver's failure boundaries."""

import functools
import http.client
import json
from pathlib import Path
import signal
import struct
import subprocess
import tempfile
import threading
import unittest
from unittest import mock
import zlib

import test_linux_browser as smoke


def png(background=b"\x2c\xa0\x5a", stale_edge=False, text=True, chrome=False):
    width, height = 320, 240

    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data)))

    rows = []
    for y in range(height):
        row = bytearray(background * width)
        if chrome and y < 60:
            row[:] = b"\xff" * (width * 3)
        if text and 80 <= y < 100:
            row[30:90] = b"\xff" * 60
        if stale_edge:
            row[-50 * 3:] = b"\0" * (50 * 3)
        rows.append(b"\0" + row)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))


class LinuxBrowserSmokeTest(unittest.TestCase):
    def test_webgl_pixel_check_rejects_an_unexecuted_blank_or_corrupt_canvas(self):
        def capture(broken=False):
            width, height = 320, 160
            data = bytearray()
            for y in range(height):
                data.append(0)
                for x in range(width):
                    color = (255, 255, 255)
                    if 60 <= y < 124 and x < 128:
                        color = ((255, 0, 0) if y < 92 else (0, 0, 255)) if x < 64 else (
                            (0, 255, 0) if y < 92 else (255, 255, 0))
                    if broken and x == 80 and y == 100:
                        color = (0, 0, 0)
                    data.extend(color)
            def chunk(kind, payload):
                return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload))
            return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(data))) + chunk(b'IEND', b'')
        smoke.check_webgl_pixels(capture())
        with self.assertRaisesRegex(AssertionError, 'WebGL1/WebGL2'):
            smoke.check_webgl_pixels(capture(broken=True))
        with self.assertRaisesRegex(AssertionError, 'WebGL1/WebGL2'):
            smoke.check_webgl_pixels(png())

    def test_fixture_responses_forbid_reuse_between_trust_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "linux.html").write_text("<!doctype html><title>Fixture</title>")
            server = smoke.http.server.ThreadingHTTPServer(
                ("127.0.0.1", 0), functools.partial(smoke.Handler, directory=directory))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                for path in ("/linux.html", "/keyboard", "/redirect"):
                    connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=2)
                    try:
                        connection.request("GET", path)
                        response = connection.getresponse()
                        self.assertEqual(response.getheader("Cache-Control"), "no-store")
                        response.read()
                    finally:
                        connection.close()
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=2)

    def test_private_state_does_not_inherit_profile_proxy_or_tab_group(self):
        inherited = dict(VOX_PROFILE_DIR="/user/profile", VOX_TAB_GROUP="/other/tabs",
                         VOX_TAB_ID="other", VOX_PROXY="socks5://ambient",
                         HTTPS_PROXY="http://ambient", SSL_CERT_FILE="/user/cert",
                         VOX_COOKIE_FILE="/user/cookies", VOX_ARENA_POISON="1")
        original = dict(inherited)
        with tempfile.TemporaryDirectory() as directory:
            environment = smoke.smoke_environment(directory, inherited)
            self.assertEqual(inherited, original)
            for name in ("VOX_TAB_GROUP", "VOX_TAB_ID", "VOX_PROXY", "HTTPS_PROXY", "SSL_CERT_FILE"):
                self.assertNotIn(name, environment)
            self.assertEqual(environment["VOX_ARENA_POISON"], "1")
            self.assertEqual(environment["VOX_TAB_EXIT_DIAGNOSTICS"], "1")
            self.assertEqual(environment["VOX_COOKIE_FILE"], "")
            self.assertEqual(environment["LIBGL_ALWAYS_SOFTWARE"], "1")
            self.assertEqual(Path(environment["VOX_PROFILE_DIR"]), Path(directory) / "profile")
            self.assertFalse(json.loads((Path(environment["VOX_PROFILE_DIR"]) / "settings.json").read_text())["enabled"])
            self.assertTrue((Path(environment["XDG_CONFIG_HOME"]) / "vox/no-update-check").is_file())

    def test_missing_window_dependency_is_failure_not_skip(self):
        with mock.patch.object(smoke.shutil, "which", side_effect=lambda name: None if name == "scrot" else name):
            with self.assertRaisesRegex(RuntimeError, "Missing Linux smoke dependencies: scrot"):
                smoke.require_tools()

    def test_each_wait_gets_its_own_deadline(self):
        clock = mock.Mock(side_effect=[0, 0, 0.2, 10, 10, 10.2])
        with mock.patch.object(smoke.time, "monotonic", clock), mock.patch.object(smoke.time, "sleep"):
            for _ in range(2):
                predicate = mock.Mock(side_effect=[False, "ready"])
                self.assertEqual(smoke.wait_for("phase", predicate, timeout=1), "ready")

    def test_wait_rejects_early_exit_even_if_window_predicate_would_pass(self):
        browser = mock.Mock(returncode=7)
        browser.poll.return_value = 7
        predicate = mock.Mock(return_value=True)
        with self.assertRaisesRegex(AssertionError, "exited 7.*window"):
            smoke.wait_for("window", predicate, browser)
        predicate.assert_not_called()

    def test_wait_times_out_with_phase_name(self):
        with mock.patch.object(smoke.time, "monotonic", side_effect=[0, 0, 2]), mock.patch.object(smoke.time, "sleep"):
            with self.assertRaisesRegex(AssertionError, "Timed out waiting for child process reaped"):
                smoke.wait_for("child process reaped", lambda: False, timeout=1)

    def test_tab_exit_requires_matching_pid_and_complete_diagnostic(self):
        self.assertFalse(smoke.successful_tab_exit("unrelated browser output\n", 42))
        self.assertFalse(smoke.successful_tab_exit("VOX_TAB_EXIT pid=43 code=0 signal=0\n", 42))
        self.assertFalse(smoke.successful_tab_exit("VOX_TAB_EXIT pid=42 code=0", 42))
        self.assertTrue(smoke.successful_tab_exit(
            "unrelated browser output\nVOX_TAB_EXIT pid=43 code=7 signal=0\n"
            "VOX_TAB_EXIT pid=42 code=0 signal=0\nmore output\n", 42))

    def test_tab_exit_rejects_nonzero_and_signalled_children(self):
        for code, signum in ((7, 0), (-1, 11), (-1, 15)):
            with self.subTest(code=code, signal=signum):
                with self.assertRaisesRegex(AssertionError, f"code={code} signal={signum}"):
                    smoke.successful_tab_exit(f"VOX_TAB_EXIT pid=42 code={code} signal={signum}\n", 42)

    def test_tab_exit_rejects_duplicate_status_records(self):
        with self.assertRaisesRegex(AssertionError, "Duplicate exit diagnostics"):
            smoke.successful_tab_exit("VOX_TAB_EXIT pid=42 code=0 signal=0\n" * 2, 42)

    def test_paint_readback_requires_current_document_and_resized_edge(self):
        smoke.check_rendered_pixels(png(), size=(320, 240))
        smoke.check_rendered_pixels(png(chrome=True), size=(320, 240))
        with self.assertRaisesRegex(AssertionError, "Missing page background"):
            smoke.check_rendered_pixels(png(), background=b"\x39\x4c\xad")
        with self.assertRaisesRegex(AssertionError, "right edge"):
            smoke.check_rendered_pixels(png(stale_edge=True))
        with self.assertRaisesRegex(AssertionError, "Wrong captured size"):
            smoke.check_rendered_pixels(png(), size=(960, 720))
        with self.assertRaisesRegex(AssertionError, "Missing retained text"):
            smoke.check_rendered_pixels(png(text=False))
        with self.assertRaisesRegex(AssertionError, "Missing retained text"):
            smoke.check_rendered_pixels(png(text=False, chrome=True))

    def test_window_search_intersects_process_and_visible_title(self):
        result = subprocess.CompletedProcess([], 0, "1234\n", "")
        with mock.patch.object(smoke.subprocess, "run", return_value=result) as execute:
            self.assertEqual(smoke.visible_window("Original", 42), "1234")
        command = execute.call_args.args[0]
        self.assertIn("--onlyvisible", command)
        self.assertIn("--all", command)
        self.assertEqual(command[-4:], ["--pid", "42", "--name", "Original"])
        self.assertEqual(execute.call_args.kwargs["timeout"], 5)

    def test_failure_cleanup_kills_group_even_if_launcher_already_exited(self):
        browser = mock.Mock(pid=42)
        browser.wait.return_value = 0
        with mock.patch.object(smoke.os, "killpg") as kill, mock.patch.object(smoke, "process_group_alive", return_value=True):
            smoke.terminate_process_group(browser)
        self.assertEqual(kill.call_args_list, [mock.call(42, signal.SIGTERM), mock.call(42, signal.SIGKILL)])

    def test_failure_cleanup_escalates_after_bounded_wait(self):
        browser = mock.Mock(pid=42)
        browser.wait.side_effect = [subprocess.TimeoutExpired("browser", 5), -9]
        with mock.patch.object(smoke.os, "killpg") as kill, mock.patch.object(smoke, "process_group_alive", return_value=True):
            smoke.terminate_process_group(browser)
        self.assertEqual(kill.call_args_list[-1], mock.call(42, signal.SIGKILL))
        self.assertEqual(browser.wait.call_args_list, [mock.call(timeout=5), mock.call(timeout=5)])

    def test_failure_and_timeout_keep_completed_phase_output(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "window-driver.log"
            result = subprocess.CompletedProcess([], 1, "PASS: startup\nFAILED: redraw\n")
            with mock.patch.object(smoke.subprocess, "run", return_value=result):
                with self.assertRaises(RuntimeError):
                    smoke.run(["driver"], log_path=log)
            self.assertEqual(log.read_text(), result.stdout)
            error = subprocess.TimeoutExpired("driver", 5, output=b"PASS: startup\n")
            with mock.patch.object(smoke.subprocess, "run", side_effect=error):
                with self.assertRaises(subprocess.TimeoutExpired):
                    smoke.run(["driver"], log_path=log, timeout=5)
            self.assertEqual(log.read_text(), "PASS: startup\n")


if __name__ == "__main__":
    unittest.main()
