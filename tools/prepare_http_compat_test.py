import tempfile
import unittest
from pathlib import Path

from prepare_http_compat import (patch_request, remove_obsolete_entries,
                                 remove_unused_private_helper, staged_modules)


class HTTPCompatibilityStagingTest(unittest.TestCase):
    def test_obsolete_helpers_are_removed_only_when_no_callers_remain(self):
        declaration = "// Helper description.\n@[inline]\nfn helper(value string) string {\n\treturn value\n}\n"
        unused = "module http\n\n" + declaration + "\n// helper() was used by an old API.\n"
        self.assertNotIn("fn helper", remove_unused_private_helper(unused, "helper"))
        used = unused + "fn caller() string {\n\treturn helper('value')\n}\n"
        self.assertEqual(used, remove_unused_private_helper(used, "helper"))
        callback = unused + "fn caller() {\n\tcallback := helper\n\tcallback('value')\n}\n"
        self.assertEqual(callback, remove_unused_private_helper(callback, "helper"))
        self.assertEqual("module http\n", remove_unused_private_helper("module http\n", "helper"))

    def test_current_cookie_api_still_updates_deprecated_pointer_casts(self):
        source = 'cookie_header_value_with_header(header)\nu64(usize(data.str))'
        patched = patch_request(source)
        self.assertIn('u64(voidptr(data.str))', patched)
        self.assertEqual(patched, patch_request(patched))

    def test_different_compiler_libraries_have_independent_modules(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            first = staged_modules(work, work / "first/vlib")
            second = staged_modules(work, work / "second/vlib")
            self.assertNotEqual(first, second)
            self.assertEqual(first, staged_modules(work, work / "first/vlib"))

    def test_removed_compiler_files_do_not_survive_a_refresh(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            target.mkdir()
            (source / "request.v").write_text("current request")
            (target / "request.v").write_text("patched request")
            (target / "vox_h2_wake.h").write_text("generated helper")
            old_source = root / "old_reverse_proxy.v"
            old_source.write_text("uses a field absent from the current request")
            (target / "reverse_proxy.v").symlink_to(old_source)
            remove_obsolete_entries(target, source)
            self.assertEqual({p.name for p in target.iterdir()},
                             {"request.v", "vox_h2_wake.h"})
            self.assertTrue(old_source.is_file())
            self.assertEqual((target / "request.v").read_text(), "patched request")


if __name__ == "__main__":
    unittest.main()
