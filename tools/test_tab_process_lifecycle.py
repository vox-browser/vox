#!/usr/bin/env python3
"""Check the production POSIX tab reaper's opt-in exit diagnostics.

The small C fixture includes the real process header and launches real children.
No V compiler, browser binary, native graphics libraries or display are required.
"""

import os
from pathlib import Path
import shlex
import signal
import subprocess
import tempfile
import unittest


FIXTURE = r'''
#include <assert.h>
#include <time.h>
#include "browsertabs/process.h"

int main(int argc, char **argv) {
    assert(argc == 3);
    int gate[2];
    assert(pipe(gate) == 0);
    pid_t child = fork();
    assert(child >= 0);
    if (child == 0) {
        close(gate[1]);
        char ready;
        ssize_t count;
        do { count = read(gate[0], &ready, 1); } while (count < 0 && errno == EINTR);
        close(gate[0]);
        if (count != 1) _exit(126);
        int value = atoi(argv[2]);
        if (strcmp(argv[1], "signal") == 0) {
            signal(value, SIG_DFL);
            raise(value);
            _exit(125);
        }
        _exit(value);
    }
    close(gate[0]);
    printf("%d\n", (int)child);
    fflush(stdout);
    // The pipe prevents an exit racing this nonblocking pending-child check.
    assert(vox_tabs_reap((int)child) == 0);
    assert(vox_tabs_reap(0) == 0);
    assert(write(gate[1], "x", 1) == 1);
    close(gate[1]);
    struct timespec delay = {0, 1000000};
    for (int attempt = 0; attempt < 5000; ++attempt) {
        if (vox_tabs_reap((int)child)) {
            // Preserve ECHILD's completed result, without repeating a report.
            assert(vox_tabs_reap((int)child) == 1);
            assert(vox_tabs_reap((int)child) == 1);
            assert(vox_tabs_reap(-1) == 1);
            return 0;
        }
        nanosleep(&delay, NULL);
    }
    kill(child, SIGKILL);
    waitpid(child, NULL, 0);
    return 2;
}
'''


class TabProcessLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix="vox-tab-process-")
        cls.addClassCleanup(cls.directory.cleanup)
        temporary = Path(cls.directory.name)
        source = temporary / "probe.c"
        source.write_text(FIXTURE)
        cls.binary = temporary / "probe"
        repo = Path(__file__).resolve().parent.parent
        command = shlex.split(os.environ.get("CC", "cc")) + [
            "-std=c11", "-D_GNU_SOURCE=1", "-Wall", "-Wextra", "-Werror",
            "-Wno-unused-function", "-I", str(repo), str(source), "-o", str(cls.binary),
        ]
        result = subprocess.run(command, text=True, capture_output=True, timeout=30)
        if result.returncode:
            raise RuntimeError(f"Tab process fixture compilation failed:\n{result.stdout}{result.stderr}")

    def run_child(self, mode, value, diagnostics="1"):
        environment = dict(os.environ)
        environment.pop("VOX_TAB_EXIT_DIAGNOSTICS", None)
        if diagnostics is not None:
            environment["VOX_TAB_EXIT_DIAGNOSTICS"] = diagnostics
        process = subprocess.Popen([str(self.binary), mode, str(value)], env=environment,
                                   text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        try:
            output, errors = process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            output, errors = process.communicate(timeout=5)
            self.fail(f"Tab process fixture timed out:\n{output}{errors}")
        self.assertEqual(process.returncode, 0, output + errors)
        return int(output.strip()), errors

    def test_successful_exit_is_reported_once_after_reaping(self):
        pid, output = self.run_child("exit", 0)
        self.assertEqual(output, f"VOX_TAB_EXIT pid={pid} code=0 signal=0\n")

    def test_nonzero_exit_is_not_reported_as_success(self):
        pid, output = self.run_child("exit", 23)
        self.assertEqual(output, f"VOX_TAB_EXIT pid={pid} code=23 signal=0\n")

    def test_signal_death_is_distinct_from_a_normal_exit(self):
        pid, output = self.run_child("signal", signal.SIGTERM)
        self.assertEqual(output, f"VOX_TAB_EXIT pid={pid} code=-1 signal={signal.SIGTERM}\n")

    def test_default_reaping_remains_silent_for_every_exit_kind(self):
        for mode, value in (("exit", 0), ("exit", 23), ("signal", signal.SIGTERM)):
            with self.subTest(mode=mode, value=value):
                _, output = self.run_child(mode, value, diagnostics=None)
                self.assertEqual(output, "")

    def test_diagnostics_require_explicit_opt_in(self):
        for setting in ("", "0", "true"):
            with self.subTest(setting=setting):
                _, output = self.run_child("exit", 0, diagnostics=setting)
                self.assertEqual(output, "")


if __name__ == "__main__":
    if os.name != "posix":
        raise SystemExit("Run the POSIX tab lifecycle checks on a Unix host")
    unittest.main()
