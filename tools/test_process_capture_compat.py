"""Check native capture declarations against V's emitted os binding types."""

import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


class ProcessCaptureCompatibilityTest(unittest.TestCase):
    def test_capture_header_coexists_with_generated_prototypes(self):
        header = (Path(__file__).resolve().parents[1]
                  / "native/include/native_process_capture_compat.h")
        # os_nix.c.v binds &char / &&char. FastC can emit these declarations
        # in the same unit as the native include, in either include order.
        prototypes = """
int v_os_execute_capture_start(char *, int *, int *);
int v_os_exec_capture_start(char **, int *, int *);
"""
        use = """
int (*shell_capture)(char *, int *, int *) = v_os_execute_capture_start;
int (*argv_capture)(char **, int *, int *) = v_os_exec_capture_start;
"""
        include = '#include "' + str(header) + '"\n'
        compiler = shlex.split(os.environ.get("CC", "cc"))
        with tempfile.TemporaryDirectory(prefix="vox-capture-compat-") as directory:
            source = Path(directory) / "capture.c"
            for order in ("generated-first", "header-first"):
                with self.subTest(order=order):
                    source.write_text((prototypes + include if order == "generated-first"
                                       else include + prototypes) + use)
                    result = subprocess.run(
                        [*compiler, "-std=c11", "-Werror", "-fsyntax-only", str(source)],
                        capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
