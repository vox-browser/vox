import copy
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest

from benchmark_hn_engines import PAGE, SCRIPT, add_image_aliases, validate, validate_memory, validate_visit_memory, build_receipts, evaluate_memory_target


class HNEngineEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.pins = {str(PAGE): 'page', str(SCRIPT): 'script'}
        common = dict(rows=101, cycles=100, collapse_verified=True, classes_restored=True,
                      native_context=False, script_sha256='script', page_sha256='page',
                      initialization_ms=1, first_cycle_ms=1, callback_ms=1,
                      compile_finish_ms=1, total_ms=4, activity=dict(entries=0))
        self.cold = dict(common, mode='libjs-cold', frontend=dict(hits=0, misses=1), cache=dict(
            last_error='', invalid_entries=0, compiler_invocations=1, cache_hits=0,
            cache_misses=3, compiled_executables=3, pending_executables=0))
        self.warm = dict(common, mode='libjs-process-warm', frontend=dict(hits=1, misses=0), cache=dict(
            last_error='', invalid_entries=0, compiler_invocations=0, cache_hits=3,
            cache_misses=0, compiled_executables=0, pending_executables=0))

    def check_pair(self, cold=None, warm=None, diagnostic=False):
        validate([cold or self.cold, warm or self.warm], 'libjs', 100, diagnostic, self.pins)

    def test_memory_target_uses_both_warm_maxima_and_exact_integer_boundaries(self):
        summary = {'v8': {'min': 1000}, 'libjs-warm': {'max': 499},
                   'libjs-process-warm': {'max': 500}, 'libjs-cold': {'max': 100000}}
        self.assertTrue(evaluate_memory_target(summary, 50)['passed'])
        summary['libjs-process-warm']['max'] = 501
        self.assertFalse(evaluate_memory_target(summary, 50)['passed'])
        summary['libjs-process-warm']['max'] = 400
        summary['libjs-warm']['max'] = 501
        self.assertFalse(evaluate_memory_target(summary, 50)['passed'])
        for percent in [0, 101, 50.0, True]:
            with self.subTest(percent=percent), self.assertRaises(ValueError):
                evaluate_memory_target(summary, percent)

    def test_timed_cohort_rejects_primitive_property_key_diagnostics(self):
        with self.assertRaises(ValueError):
            self.check_pair(warm=dict(self.warm, property_key_activity=dict(strings=1, symbols=0)))

    def test_timed_cohort_rejects_builtin_profile_even_when_other_counters_are_zero(self):
        cold = dict(self.cold, builtin_profile=[dict(name='split', calls=1)])
        with self.assertRaises(ValueError):
            self.check_pair(cold=cold)

    def test_sealed_build_receipts_bind_source_provenance_to_the_measured_output(self):
        with TemporaryDirectory() as temporary:
            binary = (Path(temporary) / 'benchmark').resolve()
            self.assertEqual(build_receipts(binary), ([], None))
            directory = binary.with_name(binary.name + '.build')
            directory.mkdir()
            (directory / 'configuration.json').write_text(json.dumps(dict(c_mode='single')))
            (directory / 'source-manifest.json').write_text(json.dumps({'source.v': 'sha'}))
            frozen = dict(complete=True, compiler_exit=0, compiler_command=['clang', '-o', str(binary)], source_inputs={'head': 'commit'})
            path = directory / 'frozen-compile.json'
            path.write_text(json.dumps(frozen))
            files, metadata = build_receipts(binary)
            self.assertEqual(len(files), 3)
            self.assertEqual(metadata['source_inputs']['head'], 'commit')
            for change in [dict(complete=False), dict(compiler_exit=1), dict(compiler_command=['clang', '-o']), dict(compiler_command=['clang', '-o', '/another/binary'])]:
                path.write_text(json.dumps(dict(frozen, **change)))
                with self.subTest(change=change), self.assertRaises(ValueError):
                    build_receipts(binary)

    def test_rejects_missing_inconsistent_or_accidentally_enabled_memory_probe(self):
        process = dict(peak_rss_bytes=1000)
        visits = [dict(self_peak_rss_bytes=500), dict(self_peak_rss_bytes=700)]
        validate_visit_memory(visits, process, True)
        validate_visit_memory([{}], process, False)
        for values in [[{}, {}], [dict(self_peak_rss_bytes=-1)],
                       [dict(self_peak_rss_bytes=1001)], list(reversed(visits))]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                validate_visit_memory(values, process, True)
        with self.assertRaises(ValueError):
            validate_visit_memory(visits, process, False)

    @unittest.skipUnless(sys.platform in ('darwin', 'linux') and shutil.which('clang'), 'Unix clang needed')
    def test_self_peak_excludes_compiler_child_and_uses_bytes(self):
        header = Path(__file__).resolve().parents[1] / 'sites/engine_peak_rss.h'
        source = '#include "' + str(header) + '"\n' + r'''
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
int main(void) {
    pid_t pid = fork();
    if (pid < 0) return 2;
    if (pid == 0) {
        volatile char *data = malloc(64 * 1024 * 1024);
        if (!data) _exit(3);
        for (size_t n = 0; n < 64 * 1024 * 1024; n += 4096) data[n] = 1;
        _exit(0);
    }
    struct rusage child; int status;
    if (wait4(pid, &status, 0, &child) != pid || status) return 4;
    uint64_t peak = child.ru_maxrss;
#if !defined(__APPLE__)
    peak *= 1024;
#endif
    printf("%llu %llu", (unsigned long long)vox_hn_self_peak_rss_bytes(), (unsigned long long)peak);
}
'''
        with TemporaryDirectory() as directory:
            binary = Path(directory) / 'rss'
            subprocess.run(['clang', '-O0', '-x', 'c', '-', '-o', str(binary)], input=source,
                           text=True, capture_output=True, check=True)
            result = subprocess.run([str(binary)], text=True, capture_output=True, check=True)
            own, child = map(int, result.stdout.split())
            self.assertGreater(own, 0)
            self.assertGreater(child, 32 * 1024 * 1024)
            self.assertLess(own, child // 2)

    def test_wait4_receipt_preserves_output_exit_and_reports_child_peak_ram(self):
        with TemporaryDirectory() as directory:
            report = Path(directory) / 'process.json'
            command = [sys.executable, '-c', 'data=bytearray(8*1024*1024);print("child-output");raise SystemExit(0)']
            result = subprocess.run([sys.executable, str(Path(__file__).with_name('benchmark_hn_engines.py')),
                                     '--measure-child', str(report), *command], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), 'child-output')
            record = json.loads(report.read_text())
            validate_memory(record, command)
            self.assertGreater(record['peak_rss_bytes'], 8*1024*1024)
            for key, value in [('peak_rss_bytes', 0), ('exit', 1), ('pid', -1), ('command', [])]:
                with self.subTest(key=key), self.assertRaises(ValueError):
                    validate_memory(dict(record, **{key: value}), command)
            failure = subprocess.run([sys.executable, str(Path(__file__).with_name('benchmark_hn_engines.py')),
                                     '--measure-child', str(report), sys.executable, '-c', 'raise SystemExit(7)'])
            self.assertEqual(failure.returncode, 7)
            self.assertEqual(json.loads(report.read_text())['exit'], 7)

    def test_jsc_requires_native_context_and_exact_visit(self):
        visit = dict(self.cold, mode='jsc', native_context=True, cache=dict(last_error='', invalid_entries=0))
        validate([visit], 'jsc', 100, False, self.pins)
        with self.assertRaises(ValueError):
            validate([dict(visit, native_context=False)], 'jsc', 100, False, self.pins)
        with self.assertRaises(ValueError):
            validate([dict(visit, mode='v8')], 'jsc', 100, False, self.pins)

    def test_rejects_borrowed_argument_diagnostics_during_timing(self):
        for key in ['borrowed_arguments', 'short_string_hits', 'direct_property_reads',
                    'fresh_arrays_initialized', 'class_collection_hits', 'direct_collection_walks']:
            with self.subTest(counter=key), self.assertRaises(ValueError):
                self.check_pair(warm=dict(self.warm, **{key: 1}))

    def test_compiler_free_reopen(self):
        self.check_pair()

    def test_rejects_incomplete_or_recompiled_warm_cache(self):
        for field, value in [('compiler_invocations', 1), ('cache_hits', 2),
                             ('cache_misses', 1), ('pending_executables', 1)]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                warm = copy.deepcopy(self.warm)
                warm['cache'][field] = value
                self.check_pair(warm=warm)

    def test_rejects_fallback_wrong_fixture_and_failed_dom(self):
        for field, value in [('native_context', True), ('page_sha256', 'changed'),
                             ('collapse_verified', False), ('classes_restored', False),
                             ('rows', 100), ('callback_ms', float('nan'))]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.check_pair(warm=dict(self.warm, **{field: value}))

    def test_native_diagnostic_must_execute_and_timing_must_disable_counters(self):
        with self.assertRaises(ValueError):
            self.check_pair(diagnostic=True)
        warm = dict(self.warm, activity=dict(entries=1))
        self.check_pair(warm=warm, diagnostic=True)
        with self.assertRaises(ValueError):
            self.check_pair(warm=warm)

    def test_rejects_runtime_allocation_instrumentation_in_timed_visits(self):
        for counter in ['lookup_activity', 'argument_activity', 'builtin_key_activity', 'context_activity',
                        'primitive_activity', 'validation_activity', 'empty_scope_activity', 'index_key_activity', 'context_reuse_activity']:
            with self.subTest(counter=counter), self.assertRaises(ValueError):
                self.check_pair(warm=dict(self.warm, **{counter: dict(count=1)}))

    def test_missing_or_reordered_visits(self):
        for visits in [[self.cold], [self.warm, self.cold]]:
            with self.assertRaises(ValueError):
                validate(visits, 'libjs', 100, False, self.pins)

    def test_restart_requires_native_reuse_and_a_cold_frontend(self):
        warm = dict(self.warm, mode='libjs-warm', frontend=dict(hits=0, misses=1))
        validate([warm], 'libjs-warm', 100, False, self.pins)
        for field, value in [('frontend', dict(hits=1, misses=0)),
                             ('cache', self.cold['cache'])]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate([dict(warm, **{field: value})], 'libjs-warm', 100, False, self.pins)

    def test_discussion_base_aliases_preserve_verified_image_bytes(self):
        with TemporaryDirectory() as directory:
            assets = Path(directory)
            responses = {}
            for name in ['s.gif', 'y18.svg']:
                (assets / name).write_bytes(name.encode())
                responses['https://news.ycombinator.com/' + name] = dict(
                    sha256=hashlib.sha256(name.encode()).hexdigest())
            replay = SimpleNamespace(manifest=dict(responses=responses))
            aliases = add_image_aliases(replay, assets)
            self.assertEqual(len(aliases), 2)
            for alias, metadata in aliases.items():
                self.assertEqual(responses[alias], responses[metadata['original']])
            (assets / 's.gif').write_bytes(b'changed')
            with self.assertRaises(ValueError):
                add_image_aliases(replay, assets)


if __name__ == '__main__':
    unittest.main()
