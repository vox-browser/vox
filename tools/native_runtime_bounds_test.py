"""Exercise the actual V runtime with the browser's fixed-array inlining hints.

Run inside tools/run_memory_bounded.py. This compiles a small fixture, not the
browser, and checks the runtime panic path as well as both valid endpoints.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
COMPILER = os.environ.get("V_BIN") or shutil.which("v") or str(Path.home() / "code/v/v")


class RuntimeBoundsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="vox-runtime-bounds-")
        cls.addClassCleanup(cls.temporary.cleanup)
        work = Path(cls.temporary.name)
        fixture = work / "main.v"
        fixture.write_text('''module main
import os
#include "HEADER"
fn main() {
    values := [11, 22, 33, 44]!
    match os.args[1] {
        'int' { println(values[os.args[2].int()]) }
        'i64' { println(values[os.args[2].i64()]) }
        'u64' { println(values[os.args[2].u64()]) }
        else { panic('unknown index type') }
    }
}
'''.replace("HEADER", (ROOT / "native_runtime_bounds.h").as_posix()))
        cls.binary = work / "bounds"
        subprocess.run([COMPILER, "-memory-limit", "10G", "-cflags", "-O2",
                        "-o", str(cls.binary), str(fixture)], check=True,
                       capture_output=True, text=True, timeout=120)

    def invoke(self, kind, index):
        return subprocess.run([str(self.binary), kind, str(index)],
                              capture_output=True, text=True, timeout=10)

    def test_both_valid_endpoints_for_each_index_type(self):
        for kind in ["int", "i64", "u64"]:
            for index, expected in [(0, "11\n"), (3, "44\n")]:
                with self.subTest(kind=kind, index=index):
                    result = self.invoke(kind, index)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, expected)

    def test_bounds_and_panic_details_survive_optimization(self):
        for kind, indexes in [("int", [-1, 4]),
                              ("i64", [-9223372036854775808, -1, 4, 9223372036854775807]),
                              ("u64", [4, 18446744073709551615])]:
            for index in indexes:
                with self.subTest(kind=kind, index=index):
                    result = self.invoke(kind, index)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(f"fixed array index out of range (index: {index}, len: 4)",
                                  result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
