"""Differential checks for the Python-free build tools.

Python is only the test runner/oracle here. Build commands use the V executable.
Run under the memory guard with VOX_BUILD_TOOLS_EXE pointing at build_tools.vsh
compiled using `v -skip-running -b c -memory-limit 10G -o PATH tools/build_tools.vsh`.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import prepare_http_compat as http
import prepare_font_runtime as font
import prepare_prealloc_runtime as arena
import prepare_ui2 as ui
import prepare_gg_metal as metal
import prepare_linux_modules as linux
from http_tls_dial import patch_transport_tls, tls_dial_helper
from http_proxy_pool import patch_pooled_proxy_request, patch_pooled_proxy_transport
from http_h2_fairness import patch_h2_pooled_transport
from http_h2_receive_credit import patch_h2_mux_receive_credit
from http_h2_wakeup import patch_h2_wakeup, patch_h2_mux_read_chunk
from http_receive_buffer import patch_receive_buffer

ROOT = Path(__file__).resolve().parents[1]


class VBuildMigrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.driver = str(Path(os.environ['VOX_BUILD_TOOLS_EXE']).resolve())
        cls.compiler = os.environ.get('V_BIN', str(Path.home() / 'code/v/v'))
        cls.temporary = tempfile.TemporaryDirectory(prefix='vox-v-build-tests-')
        cls.work = Path(cls.temporary.name)
        cls.environment = dict(os.environ, VOX_BUILD_TOOLS_CACHE_ROOT=str(cls.work / 'cache'),
                               V_MACOS_V3_NO_FALLBACK='1')
        # Fail if any V helper still attempts to start Python.
        shim = cls.work / 'no-python'
        shim.mkdir()
        for name in ['python', 'python3']:
            path = shim / name
            path.write_text('#!/bin/sh\necho "Unexpected build dependency on Python" >&2\nexit 99\n')
            path.chmod(0o755)
        cls.environment['PATH'] = str(shim) + os.pathsep + os.environ['PATH']
        with tempfile.TemporaryDirectory() as probe:
            cls.vlib = http.compiler_vlib(cls.compiler, Path(probe))

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def run_tool(self, name, *args):
        return subprocess.check_output([self.driver, name, *map(str, args)],
                                       env=self.environment, text=True).strip().splitlines()[-1]

    def test_http_staging_matches_existing_patches(self):
        modules = Path(self.run_tool('prepare_http_compat', self.compiler))
        transforms = {
            'header.v': http.patch_header,
            'response.v': http.patch_response,
            'request.v': lambda s: patch_pooled_proxy_request(patch_receive_buffer(http.patch_request(s))),
            'http_proxy.v': http.patch_proxy,
            'transport.v': lambda s: patch_pooled_proxy_transport(patch_transport_tls(s)) + '\n' + tls_dial_helper(),
            'transport_h2.v': lambda s: patch_transport_tls(s, http2=True),
            'h2_pooled_transport.v': lambda s: patch_h2_wakeup(patch_h2_pooled_transport(s)),
            'h2_mux_conn.v': lambda s: patch_h2_mux_read_chunk(patch_h2_mux_receive_credit(s)),
        }
        for name, transform in transforms.items():
            with self.subTest(name=name):
                original = (self.vlib / 'net/http' / name).read_text()
                actual = (modules / 'net/http' / name).read_text()
                self.assertEqual(actual, transform(original))
        source = self.vlib / 'x/compress/brotli/compressor.v'
        self.assertEqual((modules / 'x/compress/brotli/compressor.v').read_text(),
                         http.patch_brotli_compressor(source.read_text()))
        self.assertEqual(modules, Path(self.run_tool('prepare_http_compat', self.compiler)))

    def test_ui2_staging_keeps_existing_adapters(self):
        modules = Path(self.run_tool('prepare_ui2', self.compiler))
        expected = self.work / 'python-ui'
        expected.mkdir(exist_ok=True)
        ui.prepare_gg_gradient(expected, self.vlib)
        for path in (expected / 'gg/canvas').rglob('*'):
            if path.is_file():
                self.assertEqual((modules / path.relative_to(expected)).read_bytes(), path.read_bytes(), str(path))
        if os.uname().sysname == 'Darwin':
            actual_header = Path((modules / 'sokol/c/declaration.c.v').resolve().parent / 'sokol_gfx.h')
            self.assertEqual(actual_header.read_text(), metal.patch_header(
                (self.vlib.parent / 'thirdparty/sokol/sokol_gfx.h').read_text(),
                ROOT / 'native/include/native_gg_metal_transfer.h'))
        self.assertEqual(modules, Path(self.run_tool('prepare_ui2', self.compiler)))

    def test_linux_modules_match_existing_adapters(self):
        modules = Path(self.run_tool('prepare_linux_modules', self.compiler))
        for package in ['gg', 'net/openssl', 'sokol/sapp']:
            for path in (self.vlib / package).rglob('*.v'):
                if path.name.endswith('_test.v'):
                    continue
                name = path.relative_to(self.vlib / package)
                expected = linux.patch_module(package, path.read_text())
                if package == 'gg' and str(name) == 'text_rendering.c.v':
                    expected = linux.patch_fontstash_callbacks(expected)
                self.assertEqual((modules / package / name).read_text(), expected, str(path))

    def test_guard_forwards_child_help_and_writes_report(self):
        report = self.work / 'help-child.json'
        output = self.run_tool('run_memory_bounded', '--lock', self.work / 'help-child.lock',
                               '--report', report, '--', '/bin/sh', '-c', 'printf child', '--help')
        self.assertEqual(output, 'child')
        self.assertEqual(json.loads(report.read_text())['reason'], 'completed')

    def test_match_scope_c_adapter_matches_existing_patch(self):
        from v_match_scope_cc import patch_compiler
        source = self.work / 'compiler.c'
        original = ('void v__transform__Transformer__lower_remaining_matches_in_used_fns(Transformer* t) {\n'
                    ' string old_file = t->cur_file;\n epoch++;\n t->cur_file = old_file;\n}\n')
        source.write_text(original)
        receipt = self.work / 'patched.txt'
        environment = dict(self.environment, VOX_MATCH_SCOPE_CC='/usr/bin/true',
                           VOX_MATCH_SCOPE_RECEIPT=str(receipt))
        subprocess.run([self.driver, 'v_match_scope_cc', str(source)], env=environment, check=True)
        self.assertEqual(source.read_text(), patch_compiler(original)[0])
        self.assertEqual(receipt.read_text(), 'patched\n')

    def test_parallel_compile_preserves_failure_and_fallback_behavior(self):
        from parallel_browser_compile_test import FAKE_COMPILER
        for mode, supported, expected_mode, expected_code in [
                ('split', True, 'parallel', 0), ('refuse', True, 'single', 0),
                ('split', False, 'single', 0), ('fail', True, 'failed', 1),
                ('silent', True, 'failed', 1)]:
            with self.subTest(mode=mode, supported=supported):
                root = self.work / ('parallel-' + mode + str(supported))
                root.mkdir()
                compiler = root / 'v'
                compiler.write_text(FAKE_COMPILER.format(marker='# V3_PARALLEL_CC_REQUIRE_SPLIT' if supported else '# stock'))
                compiler.chmod(0o755)
                output = root / 'Vox'
                environment = dict(self.environment, FAKE_DIR=str(root), FAKE_MODE=mode,
                                   FAKE_REQUIRE_VARIABLE='V3_PARALLEL_CC_REQUIRE_SPLIT')
                result = subprocess.run([self.driver, 'parallel_browser_compile', '--receipt', str(root),
                                         '--output', str(output), '--', str(compiler), '-b', 'c', '/repo'],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected_code, result.stderr)
                record = json.loads((root / 'c-compile.json').read_text())
                self.assertEqual(record['mode'], expected_mode)
                if expected_mode == 'parallel':
                    self.assertEqual(record['units'], 33)
                elif expected_mode == 'single':
                    self.assertFalse(output.exists())

    def test_font_runtime_matches_existing_patches(self):
        runtime = Path(self.run_tool('prepare_font_runtime', self.compiler))
        original = (self.vlib / 'x/ttf/ttf.v').read_text()
        expected = font.widen_short_loca_offsets(original)
        self.assertEqual((runtime / 'x/ttf/ttf.v').read_text(), expected)
        self.assertEqual((runtime / 'x/ttf/vox_glyph_index_init.v').read_text(),
                         font.glyph_index_initializer(expected))
        self.assertEqual(runtime, Path(self.run_tool('prepare_font_runtime', self.compiler)))

    def test_prealloc_runtime_matches_existing_patches_and_checks_tampering(self):
        base = self.work / 'arena'
        runtime = Path(self.run_tool('prepare_prealloc_runtime', self.compiler, base))
        allocation, prealloc = arena.patch_allocator(
            (self.vlib / 'builtin/allocation.c.v').read_text(),
            (self.vlib / 'builtin/prealloc.c.v').read_text())
        self.assertEqual((runtime / 'builtin/allocation.c.v').read_text(), allocation)
        self.assertEqual((runtime / 'builtin/prealloc.c.v').read_text(), prealloc)
        for name in ['closure.c.v', 'closure_nix.c.v', 'closure_windows.c.v']:
            source = (self.vlib / 'builtin/closure' / name).read_text()
            if name == 'closure.c.v':
                expected = arena.wrap_function(source, 'fn closure_init_body()',
                                              before='\tclosure_metadata_enter()\n',
                                              after='\tclosure_metadata_leave()\n')
            else:
                expected = arena.wrap_function(source, 'fn closure_mtx_lock_platform()',
                                              after='\tclosure_metadata_enter()\n')
                expected = arena.wrap_function(expected, 'fn closure_mtx_unlock_platform()',
                                              before='\tclosure_metadata_leave()\n')
            self.assertEqual((runtime / 'builtin/closure' / name).read_text(), expected)
        self.assertEqual((runtime / 'compiler/vlib/builtin').resolve(), runtime / 'builtin')
        self.assertEqual(runtime, Path(self.run_tool('prepare_prealloc_runtime', self.compiler, base)))
        (runtime / 'builtin/allocation.c.v').write_text('modified')
        result = subprocess.run([self.driver, 'prepare_prealloc_runtime', self.compiler, str(base)],
                                env=self.environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Modified staged V runtime', result.stderr)


if __name__ == '__main__':
    unittest.main()
