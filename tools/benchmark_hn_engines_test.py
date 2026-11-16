import copy
import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest

from benchmark_hn_engines import PAGE, SCRIPT, add_image_aliases, validate


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
