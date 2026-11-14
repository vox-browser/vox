import tempfile
import unittest
import subprocess
from pathlib import Path
from unittest.mock import patch

from prepare_http_compat import (patch_brotli_compressor, patch_proxy, patch_request, patch_response,
                                 remove_obsolete_entries,
                                 remove_unused_private_helper, staged_modules)
from prepare_http_compat import compiler_vlib


class CompilerRuntimeProbeTest(unittest.TestCase):
    def test_incompatible_runtime_fails_before_staging_with_an_actionable_error(self):
        failure = subprocess.CompletedProcess([], 1, '', 'undeclared string__trim_space_eq')
        with tempfile.TemporaryDirectory() as directory, \
                patch('prepare_http_compat.subprocess.run', return_value=failure) as run:
            with self.assertRaisesRegex(RuntimeError, 'matching vlib') as error:
                compiler_vlib('/selected/v', Path(directory))
            self.assertIn('string__trim_space_eq', str(error.exception))
            self.assertEqual(run.call_args.kwargs['env']['V_MACOS_V3_NO_FALLBACK'], '1')
            self.assertEqual(list(Path(directory).iterdir()), [])


class HTTPCompatibilityStagingTest(unittest.TestCase):
    def proxy_source(self, request_configuration=False):
        arguments = ", req" if request_configuration else ""
        parameter = ", req &Request" if request_configuration else ""
        configuration = ("\ttls_config := request_ssl_connect_config(req)\n"
                         if request_configuration else "")
        helper = '''
fn request_ssl_connect_config(req &Request) ssl.SSLConnectConfig {
\treturn ssl.SSLConnectConfig{
\t\tverify: req.verify
\t\tcert: req.cert
\t\tcert_key: req.cert_key
\t\tvalidate: req.validate
\t\tin_memory_verification: req.in_memory_verification
\t}
}
''' if request_configuration else ""
        return ('''module http
struct HttpProxy {
}
fn (pr &HttpProxy) http_do() {
\ts := req.build_request_headers_with(method, host_name, port, default_port, path, data,
\t\theader)!
\tmut client := pr.ssl_dial('${host_name}:${port}'ARGUMENTS)!
}
fn (pr &HttpProxy) ssl_dial(host stringPARAMETER) !&ssl.SSLConn {
CONFIGURATION\treturn previous_dial(host)
}
'''.replace('ARGUMENTS', arguments).replace('PARAMETER', parameter)
                .replace('CONFIGURATION', configuration) + helper)

    def test_proxy_tls_preserves_request_configuration_and_cleanup_for_both_apis(self):
        for current in (False, True):
            with self.subTest(current=current):
                patched = patch_proxy(self.proxy_source(current))
                self.assertEqual(patched.count("pub struct HttpProxy {"), 1)
                self.assertEqual(patched.count("pr.ssl_dial('${host_name}:${port}', req)"), 1)
                for field in ('verify', 'cert', 'cert_key', 'validate', 'in_memory_verification'):
                    self.assertRegex(patched, rf'\b{field}:\s+req\.{field}\b')
                self.assertNotIn('validate: false', patched)
                self.assertIn('mut tcp := pr.connect_tcp(host)!', patched)
                self.assertIn('tcp.set_read_timeout(req.read_timeout)', patched)
                self.assertIn('tcp.set_write_timeout(req.write_timeout)', patched)
                self.assertIn("ssl_conn.connect(mut tcp, host.all_before_last(':')) or {", patched)
                self.assertIn('tcp.close() or {}\n        ssl_conn.shutdown() or {}', patched)
                self.assertIn('ssl_conn.owns_socket = true', patched)
                self.assertIn('ssl_conn.set_read_timeout(req.read_timeout)', patched)
                self.assertNotIn('request_ssl_connect_config', patched)
                self.assertEqual(patched, patch_proxy(patched))

    def test_proxy_config_helper_remains_when_another_caller_uses_it(self):
        source = self.proxy_source(True) + '''
fn another_request(req &Request) ssl.SSLConnectConfig {
\treturn request_ssl_connect_config(req)
}
'''
        patched = patch_proxy(source)
        self.assertIn('fn request_ssl_connect_config(req &Request)', patched)
        self.assertIn('return request_ssl_connect_config(req)', patched)

    def test_proxy_rejects_mixed_missing_and_ambiguous_tls_apis(self):
        legacy = self.proxy_source()
        current = self.proxy_source(True)
        variants = (
            legacy.replace("pr.ssl_dial('${host_name}:${port}')",
                           "pr.ssl_dial('${host_name}:${port}', req)"),
            current.replace("pr.ssl_dial('${host_name}:${port}', req)",
                            "pr.ssl_dial('${host_name}:${port}')"),
            legacy.replace("pr.ssl_dial('${host_name}:${port}')", "pr.other_dial(host)"),
            current.replace('req &Request) !&ssl.SSLConn', 'config ssl.SSLConnectConfig) !&ssl.SSLConn'),
            legacy + "\npr.ssl_dial('${host_name}:${port}')\n",
            current + "\npr.ssl_dial('${host_name}:${port}', req)\n",
        )
        for source in variants:
            with self.subTest(source=source), self.assertRaisesRegex(RuntimeError, 'proxy TLS call'):
                patch_proxy(source)

    def test_proxy_tunnel_targets_remain_origin_form(self):
        for current in (False, True):
            with self.subTest(current=current):
                source = self.proxy_source(current).replace(
                    '\ts := req.build_request_headers_with(method, host_name, port, default_port, path, data,\n\t\theader)!',
                    "\tport_part := ':${port}'\n\ts := req.build_request_headers_with(method, host_name, port, default_port,\n\t\t'${host.scheme}://${host_name}${port_part}${path}', data, header)!")
                patched = patch_proxy(source)
                self.assertNotIn('port_part', patched)
                self.assertNotIn("'${host.scheme}://", patched)
                self.assertIn('path, data, header)!', patched)
        with self.assertRaisesRegex(RuntimeError, 'proxy request target'):
            patch_proxy(self.proxy_source(True).replace('default_port, path, data',
                                                       'default_port, unsupported_target, data'))

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
