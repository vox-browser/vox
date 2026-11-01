import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import wikipedia_browser_instructions as benchmark


class WikipediaInstructionTests(unittest.TestCase):
    def args(self, root, **extra):
        values = dict(vox=root/'Vox', brave=root/'Brave', output=root, url=benchmark.URL,
                      archive=None, repeat=2, expected=root/'brave.png', expected_vox=None,
                      diff_tool=root/'pixel_diff', network_deny=root/'deny.dylib',
                      replay=dict(proxy='socks5h://127.0.0.1:1234', ca='/private/cert.pem', spki='pin'))
        values.update(extra)
        return SimpleNamespace(**values)

    def report(self, root, **extra):
        values = dict(instructions=80, exit=0, unreadable_pids={}, root_final_exit_sample=True,
                      screenshot=str(root/'capture.png'), document_audit=dict(
                          url=benchmark.URL, title='Wikipedia', ready='complete',
                          fully_active=True, viewport_width=1024, viewport_height=768,
                          paint_commands=174, textLength=5455))
        values.update(extra)
        return values

    def test_loopback_proxy_is_excluded_from_dns_deny_and_scripts_are_disabled(self):
        config = benchmark.engine_config(self.args(Path('/evidence')), 'brave')
        self.assertTrue(config.chrome_disable_javascript)
        self.assertIn('--proxy-server=socks5://127.0.0.1:1234', config.chrome_extra_arg)
        self.assertIn('--ignore-certificate-errors-spki-list=pin', config.chrome_extra_arg)
        self.assertIn('--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost, EXCLUDE 127.0.0.1',
                      config.chrome_extra_arg)
        self.assertEqual(config.vox_arg, ['--disable-javascript'])

    def test_private_environment_removes_ambient_workload_changes_and_restores_on_failure(self):
        original = dict(VOX_PROFILE_DIR='/user/profile', VOX_PROXY='bad proxy',
                        VOX_CAPTURE_DOCUMENT_ONLY='1', HTTPS_PROXY='ambient proxy',
                        LADYBIRD_ENABLE_SNAPSHOT_CACHE='1', GC_INITIAL_HEAP_SIZE='1G',
                        JSC_useJIT='false', SSL_CERT_FILE='/user/cert', PATH='/bin')
        args = self.args(Path('/evidence'))
        with patch.dict(os.environ, original, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                with benchmark.archive_environment(args, 'vox', Path('/private/profile'), Path('/evidence/vox')):
                    self.assertEqual(os.environ['VOX_PROFILE_DIR'], '/private/profile')
                    self.assertEqual(os.environ['LADYBIRD_CACHE_DIR'], '/private/profile/cache')
                    self.assertEqual(os.environ['VOX_PROXY'], args.replay['proxy'])
                    self.assertEqual(os.environ['SSL_CERT_FILE'], args.replay['ca'])
                    self.assertEqual(os.environ['DYLD_INSERT_LIBRARIES'], '/evidence/deny.dylib')
                    for key in ('HTTPS_PROXY', 'GC_INITIAL_HEAP_SIZE', 'JSC_useJIT',
                                'LADYBIRD_ENABLE_SNAPSHOT_CACHE', 'VOX_CAPTURE_DOCUMENT_ONLY'):
                        self.assertNotIn(key, os.environ)
                    raise RuntimeError('capture failed')
            self.assertEqual(dict(os.environ), original)

    def test_invalid_content_or_counters_are_rejected(self):
        root = Path('/evidence')
        args = self.args(root, archive=root/'archive')
        for engine in ('vox', 'brave'):
            benchmark.validate_report(self.report(root), args, engine)
            for changes in (dict(url='chrome-error://chromewebdata/'), dict(title='Error'),
                            dict(ready='loading')):
                report = self.report(root)
                report['document_audit'].update(changes)
                with self.assertRaises(RuntimeError):
                    benchmark.validate_report(report, args, engine)
            for changes in (dict(instructions=0), dict(unreadable_pids={123: 1})):
                with self.assertRaises(RuntimeError):
                    benchmark.validate_report(self.report(root, **changes), args, engine)
            for changes in (dict(exit=None), dict(exit=-11), dict(exit=False),
                            dict(shutdown_forced=True), dict(valid=False)):
                with self.assertRaisesRegex(RuntimeError, 'exit'):
                    benchmark.validate_report(self.report(root, **changes), args, engine)
        with self.assertRaisesRegex(RuntimeError, 'final root'):
            benchmark.validate_report(self.report(root, root_final_exit_sample=False), args, 'vox')
        report = self.report(root)
        report['document_audit']['viewport_height'] = 600
        with self.assertRaisesRegex(RuntimeError, 'viewport'):
            benchmark.validate_report(report, args, 'vox')

    def test_pairs_alternate_order_and_require_exact_per_engine_references(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            args = self.args(root, expected_vox=root/'vox.png')
            with patch.object(benchmark, 'run_engine', side_effect=lambda *a: self.report(root)) as run, \
                    patch.object(benchmark, 'compare', return_value=dict(exact=True)) as compare:
                pairs = benchmark.measure_pairs(args, object())
            self.assertEqual([call.args[1] for call in run.call_args_list], ['vox', 'brave', 'brave', 'vox'])
            self.assertEqual([call.args[0] for call in compare.call_args_list],
                             [args.expected_vox, args.expected, args.expected, args.expected_vox])
            self.assertEqual(len(pairs), 2)

    def test_failed_pixel_and_counter_samples_are_saved_and_never_retried(self):
        for unreadable, exact in (({}, False), ({123: 1}, True)):
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                args = self.args(root)
                with patch.object(benchmark, 'run_engine', return_value=self.report(root, unreadable_pids=unreadable)) as run, \
                        patch.object(benchmark, 'compare', return_value=dict(exact=exact)):
                    with self.assertRaises(RuntimeError):
                        benchmark.measure_pairs(args, object())
                self.assertEqual(run.call_count, 1)
                saved = json.loads((root/'pair-1.vox.json').read_text())
                self.assertEqual(saved['instructions'], 80)
                if not unreadable:
                    self.assertFalse(saved['pixels_exact'])


if __name__ == '__main__':
    unittest.main()
