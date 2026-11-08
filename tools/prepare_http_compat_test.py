import tempfile
import unittest
from pathlib import Path

from prepare_http_compat import (patch_brotli_compressor, patch_request, patch_response,
                                 remove_obsolete_entries,
                                 remove_unused_private_helper, staged_modules)


class HTTPCompatibilityStagingTest(unittest.TestCase):
    def test_http_response_uses_the_pure_v_brotli_codec(self):
        source = ('module http\n\nimport compress.brotli\nimport compress.gzip\n'
                  '\nfn decode_response_body() { brotli.decompress(bytes)! }\n')
        expected = source.replace('import compress.brotli', 'import x.compress.brotli')
        self.assertEqual(expected, patch_response(source))
        self.assertEqual(expected, patch_response(expected))

    def test_unknown_or_ambiguous_brotli_imports_fail_before_staging(self):
        for source in ('module http\n',
                       'import compress.brotli\nimport compress.brotli\n',
                       'import x.compress.brotli\nimport x.compress.brotli\n',
                       'import compress.brotli\nimport x.compress.brotli\n'):
            with self.subTest(source=source), self.assertRaises(RuntimeError):
                patch_response(source)

    def test_brotli_encoding_never_uses_the_optional_native_fast_path(self):
        source = '''module brotli
import compress.brotli as native_brotli
pub fn compress(data []u8, params CompressParams) ![]u8 {
\tif data.len > 4096 && params.comment.len == 0 {
\t\tif compressed := native_brotli.compress(data,
\t\t\tquality: params.quality
\t\t) {
\t\t\treturn compressed
\t\t}
\t}
\treturn compress_general(data, params, window_bits)!
}
'''
        patched = patch_brotli_compressor(source)
        self.assertNotIn('native_brotli', patched)
        self.assertIn('return compress_general(data, params, window_bits)!', patched)
        self.assertEqual(patched, patch_brotli_compressor(patched))
        with self.assertRaisesRegex(RuntimeError, 'Unsupported optional native Brotli'):
            patch_brotli_compressor(source.replace('if compressed :=', 'if result :='))

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

    def test_request_targets_use_the_original_uri_instead_of_form_query_serialization(self):
        source = """fn (req &Request) method_and_url_to_response(method Method, url urllib.URL, data string, header Header) !Response {
\tp := url.escaped_path().trim_left('/')
\tpath := if url.query().len > 0 { '/${p}?${url.query().encode()}' } else { '/${p}' }
\t// cookie_header_value_with_header(header)
}
"""
        patched = patch_request(source)
        self.assertIn('path := url.request_uri()', patched)
        self.assertNotIn('url.query()', patched)
        self.assertNotIn('trim_left', patched)
        self.assertEqual(patched, patch_request(patched))

    def test_unknown_request_target_implementations_fail_before_staging(self):
        with self.assertRaisesRegex(RuntimeError, 'Unsupported HTTP request-target'):
            patch_request('fn (req &Request) method_and_url_to_response() {}')

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
