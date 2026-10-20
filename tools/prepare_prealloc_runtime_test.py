import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prepare_prealloc_runtime import prepare, validate_allocator


class PreallocAllocatorCompatibilityTest(unittest.TestCase):
    def validate(self, allocation, prealloc):
        with tempfile.TemporaryDirectory() as directory:
            builtin = Path(directory)
            (builtin / "allocation.c.v").write_text(allocation)
            (builtin / "prealloc.c.v").write_text(prealloc)
            validate_allocator(builtin)

    def test_rejects_the_unbounded_copy_that_crashes_png_reallocation(self):
        with self.assertRaisesRegex(RuntimeError, "bounded v_realloc.*V_BIN"):
            self.validate("new_ptr = malloc(n)\nC.memcpy(new_ptr, b, n)", "")

    def test_requires_the_copy_bound_helper_to_be_used_and_available(self):
        with self.assertRaisesRegex(RuntimeError, "V_BIN"):
            self.validate("C.memcpy(new_ptr, b, n)",
                          "fn prealloc_realloc_copy_size(old_data &u8, n isize) isize {}")
        with self.assertRaisesRegex(RuntimeError, "V_BIN"):
            self.validate("copy_size := prealloc_realloc_copy_size(b, n)", "")

    def test_accepts_the_supported_bounded_copy_runtime(self):
        self.validate(
            "copy_size := prealloc_realloc_copy_size(b, n)\n"
            "new_ptr = malloc(n)\nif copy_size > 0 { C.memcpy(new_ptr, b, copy_size) }",
            "fn prealloc_realloc_copy_size(old_data &u8, n isize) isize {\n"
            "if old_data == unsafe { nil } { return 0 }\nreturn n\n}",
        )

    def test_checks_the_active_library_of_a_moved_compiler(self):
        with tempfile.TemporaryDirectory() as directory:
            vlib = Path(directory) / "baked-in-vlib"
            builtin = vlib / "builtin"
            builtin.mkdir(parents=True)
            (builtin / "allocation.c.v").write_text("C.memcpy(new_ptr, b, n)")
            (builtin / "prealloc.c.v").write_text("")
            with patch("prepare_prealloc_runtime.compiler_vlib", return_value=vlib) as resolve:
                with self.assertRaisesRegex(RuntimeError, "bounded v_realloc"):
                    prepare("/moved/compiler/v")
                self.assertEqual(resolve.call_args.args[0], "/moved/compiler/v")


if __name__ == "__main__":
    unittest.main()
