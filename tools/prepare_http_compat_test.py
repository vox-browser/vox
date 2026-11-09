from concurrent.futures import ThreadPoolExecutor
import contextlib
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

from prepare_http_compat import (compiler_vlib, patch_brotli_compressor, patch_proxy,
                                 patch_request, patch_response,
                                 remove_obsolete_entries,
                                 remove_unused_private_helper, staged_modules)


class CompilerLibraryDiscoveryTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-compiler-probe-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.work = self.root / 'probe work'
        self.records = self.root / 'invocations'
        self.library = self.root / 'active compiler root/vlib'
        self.compiler = self.root / 'compiler bin/v'
        for directory in (self.work, self.records, self.library,
                          self.compiler.parent / 'vlib'):
            directory.mkdir(parents=True)
        self.compiler.write_text(f'#!{sys.executable}\n' + textwrap.dedent('''
            import json
            import os
            from pathlib import Path
            import sys
            import time

            arguments = sys.argv[1:]
            assert arguments[-2] == 'run', arguments
            probe = Path(arguments[-1])
            assert 'println(@VEXEROOT)' in probe.read_text()
            records = Path(os.environ['VOX_PROBE_TEST_RECORDS'])
            (records / (probe.parent.name + '.json')).write_text(json.dumps(arguments))
            assert arguments[arguments.index('-b') + 1] == 'c'
            assert arguments[arguments.index('-memory-limit') + 1] == '10G'
            # Model an installation without V's bundled collector or TCC.
            assert arguments[arguments.index('-gc') + 1] == 'none'
            expected_cc = os.environ['VOX_PROBE_TEST_CC']
            if expected_cc:
                assert arguments[arguments.index('-cc') + 1] == expected_cc
            else:
                assert '-cc' not in arguments
            if os.environ['VOX_PROBE_TEST_CONCURRENT'] == '1':
                deadline = time.monotonic() + 5
                while len(list(records.glob('*.json'))) < 2:
                    assert time.monotonic() < deadline, 'probes did not overlap'
                    time.sleep(0.01)
                assert probe.is_file(), 'another invocation removed this probe'
            sys.stdout.write(os.environ['VOX_PROBE_TEST_STDOUT'])
            sys.stderr.write(os.environ['VOX_PROBE_TEST_STDERR'])
            raise SystemExit(int(os.environ['VOX_PROBE_TEST_EXIT']))
        '''))
        self.compiler.chmod(0o755)
        environment = {
            'CC': '',
            'VOX_PROBE_TEST_CC': 'clang' if sys.platform.startswith('linux') else '',
            'VOX_PROBE_TEST_RECORDS': str(self.records),
            'VOX_PROBE_TEST_STDOUT': str(self.library.parent) + '\n',
            'VOX_PROBE_TEST_STDERR': '',
            'VOX_PROBE_TEST_EXIT': '0',
            'VOX_PROBE_TEST_CONCURRENT': '0',
        }
        environment_patch = patch.dict(os.environ, environment)
        environment_patch.start()
        self.addCleanup(environment_patch.stop)

    def test_linux_probe_uses_no_collector_and_the_selected_c_compiler(self):
        for cc in ('', '/custom toolchain/cc'):
            with self.subTest(cc=cc), patch('prepare_http_compat.sys.platform', 'linux'), \
                    patch.dict(os.environ, {'CC': cc, 'VOX_PROBE_TEST_CC': cc or 'clang'}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    self.assertEqual(compiler_vlib(str(self.compiler), self.work), self.library)
                self.assertEqual(stdout.getvalue(), '')
                self.assertEqual(list(self.work.iterdir()), [])

    def test_other_platforms_keep_the_compiler_default_c_backend(self):
        with patch('prepare_http_compat.sys.platform', 'darwin'), \
                patch.dict(os.environ, {'CC': '/linux-only/cc', 'VOX_PROBE_TEST_CC': ''}):
            self.assertEqual(compiler_vlib(str(self.compiler), self.work), self.library)

    def test_failure_reports_both_streams_and_the_quoted_command(self):
        with patch.dict(os.environ, {
                'VOX_PROBE_TEST_EXIT': '17',
                'VOX_PROBE_TEST_STDOUT': 'compiler frontend diagnostic\n',
                'VOX_PROBE_TEST_STDERR': 'C compiler unavailable\n'}):
            with self.assertRaises(RuntimeError) as caught:
                compiler_vlib(str(self.compiler), self.work)
        message = str(caught.exception)
        self.assertIn('exit 17', message)
        self.assertIn('compiler frontend diagnostic', message)
        self.assertIn('C compiler unavailable', message)
        arguments = json.loads(next(self.records.glob('*.json')).read_text())
        self.assertIn(shlex.join([str(self.compiler), *arguments]), message)
        self.assertEqual(list(self.work.iterdir()), [])

    def test_invalid_roots_are_rejected_before_staging(self):
        file_root = self.root / 'file-library'
        file_root.mkdir()
        (file_root / 'vlib').write_text('not a library directory')
        outputs = ('', '\n', 'relative/root\n',
                   f'{self.library.parent}\n{self.library.parent}\n',
                   str(self.root / 'missing-root') + '\n', str(file_root) + '\n')
        for output in outputs:
            with self.subTest(output=output), \
                    patch.dict(os.environ, {'VOX_PROBE_TEST_STDOUT': output}):
                with self.assertRaises(RuntimeError):
                    compiler_vlib(str(self.compiler), self.work)
                self.assertEqual(list(self.work.iterdir()), [])

    def test_parallel_probes_have_distinct_temporary_directories(self):
        with patch.dict(os.environ, {'VOX_PROBE_TEST_CONCURRENT': '1'}), \
                ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: compiler_vlib(str(self.compiler), self.work),
                                        range(2)))
        self.assertEqual(results, [self.library, self.library])
        commands = [json.loads(path.read_text()) for path in self.records.glob('*.json')]
        self.assertEqual(len(commands), 2)
        self.assertNotEqual(Path(commands[0][-1]).parent, Path(commands[1][-1]).parent)
        self.assertEqual(list(self.work.iterdir()), [])

    def test_cli_failure_keeps_stdout_empty_and_explains_the_probe_error(self):
        script = self.root / 'project/tools/prepare_http_compat.py'
        script.parent.mkdir(parents=True)
        original = Path(__file__).with_name('prepare_http_compat.py').resolve()
        shutil.copyfile(original, script)
        environment = dict(os.environ, PYTHONPATH=str(original.parent),
                           VOX_PROBE_TEST_EXIT='23',
                           VOX_PROBE_TEST_STDOUT='compiler frontend diagnostic\n',
                           VOX_PROBE_TEST_STDERR='C compiler unavailable\n')
        result = subprocess.run([sys.executable, str(script), str(self.compiler)],
                                env=environment, capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertIn('exit 23', result.stderr)
        self.assertIn('compiler frontend diagnostic', result.stderr)
        self.assertIn('C compiler unavailable', result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(list((script.parents[1] / 'Build/v/httpcompat').iterdir()), [])


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
