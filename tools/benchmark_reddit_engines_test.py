import unittest

from benchmark_reddit_engines import faster_than_v8, validate, validate_control_diagnostics


def visit():
    return dict(mode='libjs-warm', test_build=True, cycles=100, manifest_sha256='fixture',
                collapse_verified=True, classes_restored=True, probe_verified=True,
                native_context=False, initialization_ms=3, first_cycle_ms=1,
                callback_ms=10, compile_finish_ms=0, total_ms=14,
                callback_thread_cpu_ns=9000000, self_peak_rss_bytes=0,
                activity=dict(entries=0, fast_steps=0),
                cache=dict(last_error='', invalid_entries=0, pending_executables=0,
                           cache_hits=20, cache_misses=0, compiler_invocations=0))


class RedditReceiptTests(unittest.TestCase):
    def test_production_protocol_rejects_test_or_missing_mode_proof(self):
        value = visit()
        with self.assertRaises(ValueError):
            validate(value, 'libjs-warm', 100, 'fixture', production=True)
        value['test_build'] = False
        validate(value, 'libjs-warm', 100, 'fixture', production=True)
        with self.assertRaises(ValueError):
            validate(value, 'libjs-warm', 100, 'fixture')
        del value['test_build']
        with self.assertRaises(ValueError):
            validate(value, 'libjs-warm', 100, 'fixture', production=True)

    def test_native_dispatch_redistribution_preserves_total_work(self):
        before, after = visit(), visit()
        before['activity'].update(entries=42, fast_steps=100, slow_steps=20, native_binding_steps=0)
        after['activity'].update(entries=42, fast_steps=110, slow_steps=10, native_binding_steps=10)
        validate_control_diagnostics(before, after, 'native-binding-reads')
        after['activity']['slow_steps'] += 1
        with self.assertRaises(ValueError):
            validate_control_diagnostics(before, after, 'native-binding-reads')

    def test_initialization_cache_paths_require_enabled_and_disabled_proof(self):
        before, after = visit(), visit()
        for value in [before, after]:
            value['activity'].update(entries=42, fast_steps=100, slow_steps=20)
        before['cache']['accelerated_key_bytes'] = 0
        after['cache']['accelerated_key_bytes'] = 1024
        validate_control_diagnostics(before, after, 'native-cache-digests')
        after['cache']['accelerated_key_bytes'] = 0
        with self.assertRaises(ValueError):
            validate_control_diagnostics(before, after, 'native-cache-digests')

    def test_same_binary_control_requires_enabled_disabled_path_and_identical_work(self):
        before, after = visit(), visit()
        for value in [before, after]:
            value['activity'].update(entries=42, fast_steps=100, slow_steps=20)
        before['activity']['regexp_flag_getter_reads'] = 0
        after['activity']['regexp_flag_getter_reads'] = 8
        validate_control_diagnostics(before, after, 'regexp-flags')
        for key in ['entries', 'fast_steps', 'slow_steps', 'regexp_flag_getter_reads']:
            saved = before['activity'][key]
            before['activity'][key] += 1
            with self.assertRaises(ValueError):
                validate_control_diagnostics(before, after, 'regexp-flags')
            before['activity'][key] = saved
        after['activity']['regexp_flag_getter_reads'] = 0
        with self.assertRaises(ValueError):
            validate_control_diagnostics(before, after, 'regexp-flags')
        after['activity']['regexp_flag_getter_reads'] = 8
        before['cache']['cache_hits'] -= 1
        with self.assertRaises(ValueError):
            validate_control_diagnostics(before, after, 'regexp-flags')

    def test_faster_gate_retains_outliers_and_requires_total_as_well_as_callbacks(self):
        summary = {'v8':{'callback_ms':{'minimum':10},'total_ms':{'minimum':20}},
                   'libjs-warm':{'callback_ms':{'maximum':9},'total_ms':{'maximum':19}}}
        self.assertTrue(faster_than_v8(summary)['passed'])
        summary['libjs-warm']['total_ms']['maximum'] = 20
        self.assertFalse(faster_than_v8(summary)['passed'])
        summary['libjs-warm']['total_ms']['maximum'] = 19
        summary['libjs-warm']['callback_ms']['maximum'] = 11
        self.assertFalse(faster_than_v8(summary)['passed'])

    def test_complete_uninstrumented_reopen_and_separate_diagnostic(self):
        value = visit()
        validate(value, 'libjs-warm', 100, 'fixture')
        value['activity']['entries'] = 42
        validate(value, 'libjs-warm', 100, 'fixture', diagnostic=True)
        with self.assertRaises(ValueError):
            validate(value, 'libjs-warm', 100, 'fixture')

    def test_wrong_fixture_engine_work_or_compilation_cannot_pass(self):
        for key, bad in [('manifest_sha256','other'), ('cycles',99), ('native_context',True),
                         ('collapse_verified',False), ('classes_restored',False), ('probe_verified',False)]:
            with self.subTest(key=key):
                value = visit(); value[key] = bad
                with self.assertRaises(ValueError):
                    validate(value, 'libjs-warm', 100, 'fixture')
        for key in ['cache_misses','compiler_invocations','pending_executables','invalid_entries']:
            value = visit(); value['cache'][key] = 1
            with self.assertRaises(ValueError):
                validate(value, 'libjs-warm', 100, 'fixture')

    def test_invalid_intervals_and_unexpected_memory_probes_are_rejected(self):
        for key, bad in [('callback_ms',float('nan')), ('first_cycle_ms',-1),
                         ('total_ms',10), ('callback_thread_cpu_ns',0), ('self_peak_rss_bytes',123)]:
            value = visit(); value[key] = bad
            with self.assertRaises(ValueError):
                validate(value, 'libjs-warm', 100, 'fixture')


if __name__ == '__main__':
    unittest.main()
