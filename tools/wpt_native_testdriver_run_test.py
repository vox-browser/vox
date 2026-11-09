#!/usr/bin/env python3
import os
import unittest
from unittest.mock import patch
import wpt_native_testdriver_run as adapter


class NativeTestDriverRunnerTests(unittest.TestCase):
    def test_vendor_extension_preserves_harness_and_existing_overrides(self):
        resources = {'/resources/testharness.js': (b'original harness', 'text/javascript'),
                     '/resources/testharnessreport.js': (b'collector', 'text/javascript')}
        observed = []
        def capture(_server, *args):
            observed.extend(args)
        original_init = adapter.NativeInputManifestServer.__bases__[0]
        with patch.object(original_init, '__init__', capture):
            adapter.NativeInputManifestServer('root', 'support', 'runner', resources, 'alive', 'result', 'tls')
        self.assertEqual(observed[:3], ['root', 'support', 'runner'])
        self.assertEqual(observed[4:], ['alive', 'result', 'tls'])
        configured = observed[3]
        self.assertEqual({k: v for k, v in configured.items() if k != '/resources/testdriver-vendor.js'}, resources)
        self.assertNotIn('/resources/testdriver-vendor.js', resources)
        self.assertEqual(configured['/resources/testdriver-vendor.js'],
                         (adapter.VENDOR_PATH.read_bytes(), 'text/javascript'))

    def test_native_input_requires_explicit_launch_opt_in(self):
        with patch.dict(os.environ, {'VOX_WPT_TESTDRIVER': ''}), patch.object(adapter.upstream, 'main') as run:
            with self.assertRaisesRegex(SystemExit, 'VOX_WPT_TESTDRIVER=1'):
                adapter.main()
            run.assert_not_called()

    def test_runner_exit_is_preserved_and_server_registration_restored(self):
        original = adapter.upstream.ManifestServer
        def run():
            self.assertIs(adapter.upstream.ManifestServer, adapter.NativeInputManifestServer)
            return 7
        with patch.dict(os.environ, {'VOX_WPT_TESTDRIVER': '1'}), patch.object(adapter.upstream, 'main', run):
            self.assertEqual(adapter.main(), 7)
        self.assertIs(adapter.upstream.ManifestServer, original)


if __name__ == '__main__':
    unittest.main()
