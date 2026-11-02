import contextlib
import hashlib
import io
import json
import os
import re
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
    lines = ["SCROLL_START precise=1 document_width=1024 document_height=764 scale=2 input_hz=60 title=fixture"]
    for i in range(12):
        lines.append(f"SCROLL_INPUT {i} t_us={i * 10000} wheel_us=100")
    for i, (time, y) in enumerate(zip(times, positions)):
        lines.append(f"SCROLL_PUBLISH {i} t_us={time} frame_us=1000 "
                     f"input_age_us=1000 inputs={i + 1} scroll_y={y}")
    lines.append("SCROLL_DONE inputs=12 publications=12 duration_us=200000")
    return "\n".join(lines) + "\n"


class PreciseScrollTests(unittest.TestCase):
    def test_rejects_wrong_or_missing_document_viewport(self):
        summarize(log_for(), 12, expected_viewport=(1024, 764))
        for log in [log_for().replace("document_height=764", "document_height=880"),
                    log_for().replace("document_height=764", "document_height=NaN"),
                    log_for().replace("document_width=1024 ", "")]:
            with self.subTest(log=log), self.assertRaisesRegex(ValueError, "viewport"):
                summarize(log, 12, expected_viewport=(1024, 764))

    def test_launch_isolates_saved_proxy_and_bookmarks_from_user_profile(self):
        self.check_isolated_launch(False)

    def test_fixture_navigation_seeds_only_allow_any_site(self):
        self.check_isolated_launch(True)

    def test_profile_reset_is_explicitly_marked_as_diagnostic(self):
        self.check_isolated_launch(False, v_profile_reset=True)

    def test_fault_capture_is_explicitly_marked_as_diagnostic(self):
        self.check_isolated_launch(False, capture_faults=True)

    def test_fixture_profile_cannot_silently_disable_replay_proxy(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "measurement"
            def compile_probe(command, **kwargs):
                Path(command[-1]).write_bytes(b"fixture probe")
            with mock.patch.object(measure_precise_scroll.sys, "platform", "darwin"), \
                    mock.patch.object(measure_precise_scroll.sys, "argv", ["probe", "--output", str(output),
                        "--allow-fixture-navigation", "--network-policy", "fixture replay"]), \
                    mock.patch.dict(os.environ, VOX_PROXY="socks5h://127.0.0.1:9000"), \
                    mock.patch.object(measure_precise_scroll.subprocess, "run", compile_probe), \
                    mock.patch.object(measure_precise_scroll.subprocess, "Popen") as launch:
                with self.assertRaisesRegex(ValueError, "cannot combine with VOX_PROXY"):
                    measure_precise_scroll.main()
                launch.assert_not_called()

    def check_isolated_launch(self, allow_fixture_navigation, v_profile_reset=False, capture_faults=False):
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

            renderer = binary.parent / 'libLadybirdVSkiaText.dylib'
            renderer.write_bytes(b'fixture renderer')

            def launch(command, **kwargs):
                env = kwargs["env"]
                self.assertEqual(Path(env["VOX_PROFILE_DIR"]), output / "profile")
                profile_files = list((output / "profile").iterdir())
                self.assertEqual([p.name for p in profile_files],
                                 ["settings.json"] if allow_fixture_navigation else [])
                if allow_fixture_navigation:
                    self.assertEqual(json.loads(profile_files[0].read_text()), {"allow_any_site": True})
                self.assertEqual(command[command.index("--window-height") + 1], "876")
                self.assertNotIn("--enable-javascript", command)
                self.assertNotIn("--disable-javascript", command)
                self.assertEqual(env["VOX_PROXY"], "" if allow_fixture_navigation else "http://127.0.0.1:9")
                self.assertEqual(env["SSL_CERT_FILE"], str(certificate))
                self.assertNotIn("VOX_PROFILE_FRAMES", env)
                self.assertNotIn("DYLD_LIBRARY_PATH", env)
                self.assertEqual(env["VOX_PRECISE_REQUIRED_TITLE"], "fixture")
                self.assertEqual(env["VOX_PRECISE_RESET_V_PROFILE"], "1" if v_profile_reset else "")
                self.assertEqual(env["VOX_PRECISE_CAPTURE_FAULTS"], "1" if capture_faults else "")
                kwargs["stdout"].write(log_for())
                kwargs["stdout"].write('SCROLL_IMAGE name=libLadybirdVSkiaText.dylib path_hex='
                                       + os.fsencode(renderer).hex() + '\n')
                return mock.Mock(pid=123, wait=mock.Mock(return_value=0))

            arguments = ["probe", "--binary", str(binary), "--output", str(output),
                         "--inputs", "12", "--network-policy", "fixture offline route",
                         "--require-title", "fixture",
                         "--script-policy", "automatic",
                         "--env", f"VOX_PROFILE_DIR={user_profile}"]
            if allow_fixture_navigation:
                arguments.append("--allow-fixture-navigation")
            if v_profile_reset:
                arguments.append("--v-profile-reset")
            if capture_faults:
                arguments.append("--capture-faults")
            with mock.patch.object(measure_precise_scroll.sys, "platform", "darwin"), \
                    mock.patch.object(measure_precise_scroll.sys, "argv", arguments), \
                    mock.patch.dict(measure_precise_scroll.os.environ,
                                    VOX_PROFILE_DIR=str(user_profile), VOX_PROFILE_FRAMES="600",
                                    DYLD_LIBRARY_PATH="/unrelated/native/libraries",
                                    VOX_PRECISE_RESET_V_PROFILE="ambient-must-not-enable-profiling",
                                    VOX_PRECISE_CAPTURE_FAULTS="1",
                                    SSL_CERT_FILE=str(certificate),
                                    VOX_PROXY="" if allow_fixture_navigation else "http://127.0.0.1:9"), \
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
            self.assertEqual(evidence["diagnostic_only"], v_profile_reset or capture_faults)
            header = Path(measure_precise_scroll.__file__).with_name("precise_scroll_faults.h")
            self.assertEqual(evidence["source_and_binary_sha256"][str(header)],
                             hashlib.sha256(header.read_bytes()).hexdigest())
            self.assertEqual("seeded only" in evidence["initial_profile"], allow_fixture_navigation)
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

    def test_native_images_reject_shared_paths_missing_records_and_malformed_paths(self):
        binary = Path('/tmp/selected bundle/Vox')
        name = 'libLadybirdVSkiaText.dylib'
        selected = binary.parent / name
        good = f'SCROLL_IMAGE name={name} path_hex={os.fsencode(selected).hex()}\n'
        self.assertEqual(measure_precise_scroll.verify_native_images(good, binary), {name: str(selected.resolve())})
        for bad in ['', good.replace(os.fsencode(selected).hex(), os.fsencode('/tmp/Build/v/' + name).hex()),
                    f'SCROLL_IMAGE name={name} path_hex=invalid\n',
                    f'SCROLL_IMAGE name=../{name} path_hex={os.fsencode(selected).hex()}\n']:
            with self.subTest(log=bad), self.assertRaises(ValueError):
                measure_precise_scroll.verify_native_images(bad, binary)

    @unittest.skipUnless(sys.platform == "darwin", "macOS native fault capture")
    def test_native_fault_capture_preserves_first_registers_and_disabled_handler(self):
        with tempfile.TemporaryDirectory(prefix="fault fixture ü ") as temporary:
            root = Path(temporary)
            header = Path(measure_precise_scroll.__file__).with_name("precise_scroll_faults.h")
            source, binary = root / "fixture.c", root / "fixture"
            source.write_text('#include <CoreFoundation/CoreFoundation.h>\n#include "' + str(header) + '"\n' + r'''
                static void original(int sig) {(void)sig; _exit(73);}
                static void fail(void *unused) {
                    if (unused) {
                        // libdispatch workers can inherit a blocked SIGBUS.
                        sigset_t signals;
                        sigemptyset(&signals); sigaddset(&signals, SIGBUS);
                        sigprocmask(SIG_UNBLOCK, &signals, NULL);
                        raise(SIGBUS); _exit(2);
                    }
                    volatile int value = *(volatile int *)0x5100000001eULL;
                    (void)value;
                    _exit(2);
                }
                int main(int argc, char **argv) {
                    (void)argv;
                    signal(SIGSEGV, original);
                    signal(SIGBUS, original);
                    scroll_fault_schedule();
                    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, 200000000),
                        dispatch_get_main_queue(), argc > 1 ? (void *)1 : NULL, fail);
                    CFRunLoopRun();
                    return 0;
                }
            ''')
            subprocess.run(["clang", "-O2", "-Wall", "-Wextra", "-Werror", str(source),
                            "-framework", "CoreFoundation", "-o", str(binary)], check=True)
            for enabled, bus in [("", False), ("0", False), ("1", False), ("", True), ("1", True)]:
                env = dict(os.environ, VOX_PRECISE_CAPTURE_FAULTS=enabled)
                result = subprocess.run([str(binary), *(["bus"] if bus else [])], env=env, capture_output=True, text=True,
                                        timeout=10)
                if enabled != "1":
                    self.assertEqual(result.returncode, 73, (enabled, bus, result.stderr))
                    self.assertNotIn("SCROLL_FAULT_", result.stderr)
                    continue
                self.assertEqual(result.returncode, 138 if bus else 139)
                fault = re.search(r"SCROLL_FAULT_FIRST signal=([0-9a-f]+) address=([0-9a-f]+) pc=([0-9a-f]+)", result.stderr)
                self.assertIsNotNone(fault)
                self.assertEqual(int(fault[1], 16), 10 if bus else 11)
                if not bus:
                    self.assertEqual(int(fault[2], 16), 0x5100000001e)
                self.assertGreater(int(fault[3], 16), 0)
                self.assertIn("SCROLL_FAULT_REGISTER", result.stderr)
                self.assertIn("SCROLL_FAULT_FRAME", result.stderr)
                images = re.findall(r"SCROLL_FAULT_IMAGE header=\w+ slide=\w+ text_start=(\w+) text_end=(\w+) path_hex=(\w+)", result.stderr)
                self.assertEqual([Path(os.fsdecode(bytes.fromhex(path))).resolve()
                                  for _, _, path in images], [binary.resolve()])
                if not bus:
                    self.assertLessEqual(int(images[0][0], 16), int(fault[3], 16))
                    self.assertGreater(int(images[0][1], 16), int(fault[3], 16))
                memories = re.findall(r"SCROLL_FAULT_MEMORY address=(\w+) bytes=(\w+)", result.stderr)
                self.assertGreater(len(memories), 0)
                self.assertLessEqual(len(memories), 128)
                self.assertEqual(len(set(address for address, _ in memories)), len(memories))
                self.assertTrue(all(int(size, 16) <= 512 for _, size in memories))

    @unittest.skipUnless(sys.platform == "darwin", "macOS native image identities")
    def test_native_observer_records_the_library_actually_loaded(self):
        with tempfile.TemporaryDirectory(prefix='native image ü ') as temporary:
            root = Path(temporary)
            library = root / 'libLadybirdVSkiaText.dylib'
            stub = root / 'library.c'
            stub.write_text('int fixture_value(void) { return 17; }\n')
            subprocess.run(['clang', '-dynamiclib', str(stub), '-o', str(library)], check=True)
            observer = Path(measure_precise_scroll.__file__).with_name('measure_precise_scroll_darwin.m')
            source = root / 'image.m'
            source.write_text('#include "' + str(observer) + '"\n' + r'''
                int main(int argc, char **argv) {
                    (void)argc;
                    _dyld_register_func_for_add_image(record_native_image);
                    return dlopen(argv[1], RTLD_NOW) ? 0 : 1;
                }
            ''')
            binary = root / 'image'
            subprocess.run(['clang', '-O2', '-fobjc-arc', str(source), '-framework', 'Cocoa',
                            '-framework', 'QuartzCore', '-Wl,-undefined,dynamic_lookup',
                            '-o', str(binary)], check=True)
            result = subprocess.run([str(binary), str(library)], check=True, capture_output=True, text=True)
            self.assertEqual(measure_precise_scroll.verify_native_images(result.stderr, binary),
                             {library.name: str(library.resolve())})

    @unittest.skipUnless(sys.platform == "darwin", "macOS injected observer")
    def test_native_diagnostic_clock_uses_input_epoch(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            observer = Path(measure_precise_scroll.__file__).with_name('measure_precise_scroll_darwin.m')
            source = root / 'clock.m'
            source.write_text('#include "' + str(observer) + '"\n' + r'''
                int main(void) {
                    if (vox_precise_scroll_diagnostic_time() != -1) return 1;
                    started = CACurrentMediaTime() - 1;
                    active = YES;
                    double elapsed = vox_precise_scroll_diagnostic_time();
                    if (elapsed < 1000000 || elapsed > 1100000) return 2;
                    active = NO;
                    return vox_precise_scroll_diagnostic_time() == -1 ? 0 : 3;
                }
            ''')
            binary = root / 'clock'
            subprocess.run(['clang', '-O2', '-fobjc-arc', str(source), '-framework', 'Cocoa',
                            '-framework', 'QuartzCore', '-Wl,-undefined,dynamic_lookup',
                            '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)

    @unittest.skipUnless(sys.platform == "darwin", "macOS injected observer")
    def test_native_profile_reset_calls_real_symbol_and_rejects_missing_profiler(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            observer = Path(measure_precise_scroll.__file__).with_name("measure_precise_scroll_darwin.m")
            helper = root / "reset.m"
            helper.write_text('#include "' + str(observer) + '"\n' + r'''
                int main(int argc, char **argv) {
                    (void)argv;
                    setenv("VOX_PRECISE_RESET_V_PROFILE", argc > 1 ? "1" : "", 1);
                    reset_v_profile_if_requested();
                    return 0;
                }
            ''')
            stub = root / "profiler.c"
            stub.write_text('#include <stdio.h>\nvoid vreset_profile_stats(void) { puts("RESET_CALLED"); }\n')
            for present in [False, True]:
                binary = root / ("with-profiler" if present else "without-profiler")
                subprocess.run(["clang", "-O2", "-fobjc-arc", str(helper),
                                *([str(stub)] if present else []),
                                "-framework", "Cocoa", "-framework", "QuartzCore",
                                "-Wl,-undefined,dynamic_lookup", "-o", str(binary)], check=True)
                disabled = subprocess.run([str(binary)], capture_output=True, text=True, check=True)
                self.assertNotIn("RESET_CALLED", disabled.stdout)
                enabled = subprocess.run([str(binary), "reset"], capture_output=True, text=True)
                self.assertEqual(enabled.returncode, 0 if present else 2, enabled.stderr)
                if present:
                    self.assertIn("RESET_CALLED", enabled.stdout)
                    self.assertIn("SCROLL_PROFILE_RESET", enabled.stderr)
                else:
                    self.assertIn("profiler symbol is absent", enabled.stderr)

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

    @unittest.skipUnless(sys.platform == "darwin", "macOS precise wheel semantics")
    def test_tail_waits_for_slow_publication_and_rejects_timeout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "tail.m"
            observer = Path(measure_precise_scroll.__file__).with_name("measure_precise_scroll_darwin.m")
            source.write_text('#include "' + str(observer) + '"\n' + r'''int main(int argc, char **argv) {
                (void)argv;
                started = last_input = CACurrentMediaTime();
                inputs = input_limit = 12;
                input_samples = calloc(inputs, sizeof(Input));
                frame_samples = calloc(1, sizeof(Frame));
                if (argc > 1) last_input -= 6;
                else dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400*NSEC_PER_MSEC),
                    dispatch_get_main_queue(), ^{
                        frame_samples[0] = (Frame){CACurrentMediaTime()-started, 0, 0, 42, inputs};
                        publications = 1;
                    });
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250*NSEC_PER_MSEC),
                    dispatch_get_main_queue(), ^{ wait_for_final_publication(); });
                dispatch_main();
            }
            ''')
            binary = root / "tail"
            subprocess.run(["clang", "-O2", "-fobjc-arc", str(source),
                            "-framework", "Cocoa", "-framework", "QuartzCore",
                            "-Wl,-undefined,dynamic_lookup", "-o", str(binary)], check=True)
            for arguments, expected in [([], 0), (["timeout"], 2)]:
                result = subprocess.run([str(binary), *arguments], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, expected, result.stderr)
                if expected == 0:
                    self.assertIn("SCROLL_DONE inputs=12 publications=1", result.stderr)
                    frame = measure_precise_scroll.records(result.stderr, "SCROLL_PUBLISH")[0]
                    self.assertGreaterEqual(frame["t_us"], 400000)
                else:
                    self.assertIn("SCROLL_ERROR final input publication timed out", result.stderr)

    @unittest.skipUnless(sys.platform == "darwin", "macOS precise wheel semantics")
    def test_wheel_event_clears_physical_keyboard_modifiers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "wheel.m"
            observer = Path(measure_precise_scroll.__file__).with_name("measure_precise_scroll_darwin.m")
            source.write_text('#include "' + str(observer) + '"\n' + r'''int main(void) {
                @autoreleasepool {
                    CGEventRef cg = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, -2);
                    if (!cg) return 1;
                    CGEventSetFlags(cg, kCGEventFlagMaskShift | kCGEventFlagMaskCommand);
                    NSEvent *event = unmodified_wheel_event(cg);
                    int valid = event.modifierFlags == 0 && event.hasPreciseScrollingDeltas
                        && event.scrollingDeltaX == 0 && event.scrollingDeltaY == -2;
                    CFRelease(cg);
                    return valid ? 0 : 2;
                }
            }
            ''')
            binary = root / "wheel"
            subprocess.run(["clang", "-O2", "-fobjc-arc", str(source),
                            "-framework", "Cocoa", "-framework", "QuartzCore",
                            "-Wl,-undefined,dynamic_lookup", "-o", str(binary)], check=True)
            env = {k: v for k, v in os.environ.items() if not k.startswith("VOX_PRECISE_")}
            subprocess.run([str(binary)], env=env, check=True)

    def test_rejects_keyboard_modified_or_horizontal_wheel_samples(self):
        for field in ("modifiers=131072", "delta_x=2"):
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "Modified or horizontal"):
                summarize(log_for().replace("wheel_us=100", "wheel_us=100 " + field), 12)

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
