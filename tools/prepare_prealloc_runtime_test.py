import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prepare_prealloc_runtime import (CAPTURE_DECLARATIONS, declare_capture_helpers,
                                      patch_allocator, prepare, validate_allocator)


UNBOUNDED = """module builtin
pub fn v_realloc(b &u8, n int) &u8 {
\t$if prealloc {
\t\tunsafe {
\t\t\tnew_ptr = malloc(n)
\t\t\tC.memcpy(new_ptr, b, n)
\t\t}
\t}
}
"""
PREALLOC = "module builtin\nfn prealloc_realloc(old_data &u8, old_size int, new_size int) &u8 {}\n"


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

    def test_stages_the_known_allocator_and_leaves_bounded_versions_unchanged(self):
        allocation, prealloc = patch_allocator(UNBOUNDED, PREALLOC)
        self.assertNotIn("C.memcpy(new_ptr, b, n)", allocation)
        self.validate(allocation, prealloc)
        self.assertEqual(patch_allocator(allocation, prealloc), (allocation, prealloc))

    def test_unknown_and_partial_allocators_are_rejected(self):
        for allocation, prealloc in [
            (UNBOUNDED.replace("malloc(n)", "other_allocator(n)"), PREALLOC),
            (UNBOUNDED, PREALLOC + "fn prealloc_realloc_copy_size() {}"),
            (UNBOUNDED.replace("C.memcpy(new_ptr, b, n)", "prealloc_realloc_copy_size(b, n)"), PREALLOC),
        ]:
            with self.subTest(allocation=allocation):
                with self.assertRaisesRegex(RuntimeError, "Unsupported V allocator"):
                    patch_allocator(allocation, prealloc)

    def test_runtime_staging_preserves_compiler_sources_and_has_immutable_identities(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            vlib = base / 'v-source/vlib'
            builtin = vlib / 'builtin'
            closure = builtin / 'closure'
            closure.mkdir(parents=True)
            (builtin / 'allocation.c.v').write_text(UNBOUNDED)
            (builtin / 'prealloc.c.v').write_text(PREALLOC)
            (builtin / 'other.v').write_text('module builtin\n')
            (closure / 'closure.c.v').write_text('module closure\nfn closure_init_body() {\n}\n')
            (vlib / 'os').mkdir()
            compiler = base / 'v-source/v'
            compiler.write_bytes(b'compiler identity')
            before = {str(p): p.read_bytes() for p in vlib.rglob('*') if p.is_file()}
            with patch('prepare_prealloc_runtime.compiler_vlib', return_value=vlib):
                staged = prepare(compiler, base / 'output')
                self.assertEqual(prepare(compiler, base / 'output'), staged)
                validate_allocator(staged / 'builtin')
                self.assertEqual((staged / 'compiler/v').read_bytes(), compiler.read_bytes())
                self.assertEqual((staged / 'compiler/vlib/builtin').resolve(), staged / 'builtin')
                self.assertEqual((staged / 'compiler/vlib/os').resolve(), (vlib / 'os').resolve())
                self.assertTrue((staged / 'builtin/other.v').is_symlink())
                self.assertIn('closure_metadata_enter()', (staged / 'builtin/closure/closure.c.v').read_text())
                self.assertEqual(before, {str(p): p.read_bytes() for p in vlib.rglob('*') if p.is_file()})
                compiler.write_bytes(b'new compiler identity')
                newer = prepare(compiler, base / 'output')
                self.assertNotEqual(newer, staged)
                self.assertEqual((staged / 'compiler/v').read_bytes(), b'compiler identity')
                allocator = newer / 'builtin/allocation.c.v'
                allocator.write_text(allocator.read_text() + '\n// changed\n')
                with self.assertRaisesRegex(RuntimeError, 'modified staged V runtime'):
                    prepare(compiler, base / 'output')

    def test_staged_builtin_declares_the_os_capture_helpers(self):
        compat = 'module builtin\n\n$if !v3_c_extern_declarations ? {\n\t#include <poll.h>\n}\n'
        declared = declare_capture_helpers(compat)
        self.assertTrue(declared.startswith(compat.rstrip('\n')))
        self.assertEqual(declared.count(CAPTURE_DECLARATIONS), 1)
        self.assertEqual(declare_capture_helpers(declared), declared)
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            vlib = base / 'v-source/vlib'
            closure = vlib / 'builtin/closure'
            closure.mkdir(parents=True)
            (vlib / 'builtin/allocation.c.v').write_text(UNBOUNDED)
            (vlib / 'builtin/prealloc.c.v').write_text(PREALLOC)
            (vlib / 'builtin/c_headers_compat_nix.c.v').write_text(compat)
            (closure / 'closure.c.v').write_text('module closure\nfn closure_init_body() {\n}\n')
            compiler = base / 'v-source/v'
            compiler.write_bytes(b'compiler identity')
            with patch('prepare_prealloc_runtime.compiler_vlib', return_value=vlib):
                # Without vlib's declaration header there is nothing to include.
                staged = prepare(compiler, base / 'output')
                self.assertTrue((staged / 'builtin/c_headers_compat_nix.c.v').is_symlink())
                (vlib / 'os').mkdir()
                (vlib / 'os/execute_capture_legacy.h').write_text('int v_os_exec_capture_start(char **, int *, int *);\n')
                staged = prepare(compiler, base / 'output')
                staged_compat = staged / 'builtin/c_headers_compat_nix.c.v'
                self.assertFalse(staged_compat.is_symlink())
                self.assertIn(CAPTURE_DECLARATIONS, staged_compat.read_text())
                self.assertEqual((vlib / 'builtin/c_headers_compat_nix.c.v').read_text(), compat)

    def test_the_same_compiler_installed_at_another_path_reuses_its_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            vlib = base / 'v-source/vlib'
            closure = vlib / 'builtin/closure'
            closure.mkdir(parents=True)
            (vlib / 'builtin/allocation.c.v').write_text(UNBOUNDED)
            (vlib / 'builtin/prealloc.c.v').write_text(PREALLOC)
            (closure / 'closure.c.v').write_text('module closure\nfn closure_init_body() {\n}\n')
            built = base / 'v-source/v'
            built.write_bytes(b'compiler identity')
            installed = base / 'shared/v'
            installed.parent.mkdir()
            installed.write_bytes(built.read_bytes())
            with patch('prepare_prealloc_runtime.compiler_vlib', return_value=vlib):
                staged = prepare(built, base / 'output')
                self.assertEqual(prepare(installed, base / 'output'), staged)
                self.assertEqual((staged / 'compiler/v').read_bytes(), b'compiler identity')
                installed.write_bytes(b'another compiler')
                self.assertNotEqual(prepare(installed, base / 'output'), staged)


if __name__ == "__main__":
    unittest.main()
