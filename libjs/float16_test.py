"""Run binary16 conversion checks with and without compiler _Float16 support.

Run inside the repository's memory guard. CC can select clang, gcc or tcc.
"""

import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


class Float16Test(unittest.TestCase):
    def test_native_and_portable_conversions(self):
        fixture = Path(__file__).with_suffix(".c")
        compiler = shlex.split(os.environ.get("CC", "cc"))
        with tempfile.TemporaryDirectory(prefix="vox-float16-") as temporary:
            for portable in [False, True]:
                with self.subTest(portable=portable):
                    binary = Path(temporary) / ("portable" if portable else "native")
                    command = [*compiler, "-std=c11", "-Wall", "-Wextra", "-Werror"]
                    if portable:
                        command += ["-DVOX_TEST_NO_FLOAT16"]
                    result = subprocess.run(
                        [*command, str(fixture), "-lm", "-o", str(binary)],
                        capture_output=True, text=True, timeout=60)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    subprocess.run([str(binary)], check=True, timeout=30)


if __name__ == "__main__":
    unittest.main()
