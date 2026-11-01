import hashlib
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import reddit_browser_instructions as benchmark


class FrozenResponseTests(unittest.TestCase):
    def put(self, root, key, body=b'encoded image', status='200', final='https://example.test/image'):
        path = root/'resources'/hashlib.sha256(key.encode()).hexdigest()
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(body)
        path.with_name(path.name+'.url').write_text(final)
        path.with_name(path.name+'.headers.json').write_text(json.dumps([
            {'name':'content-type','value':'image/webp'},
            {'name':'content-encoding','value':'gzip'},
            {'name':'content-length','value':'999'},
            {'name':'access-control-allow-origin','value':'https://old.reddit.com'}]))
        if status is not None:path.with_name(path.name+'.status').write_text(status)
        return path

    def test_both_engines_receive_native_accept_variant_and_original_response_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);url='https://example.test/image'
            self.put(root,url,b'old PNG')
            path=self.put(root,url+'\nAccept: '+benchmark.IMAGE_ACCEPT)
            body,mime,selected=benchmark.frozen_response(root,url,'Image')
            self.assertEqual((body,mime,selected),(b'encoded image','image/webp',path))
            client=object.__new__(benchmark.FrozenAssetsCDP)
            headers=client.replay_headers(body,mime,path)
            self.assertNotIn('content-encoding',[h['name'] for h in headers])
            self.assertEqual([h['value'] for h in headers if h['name']=='content-length'],['13'])
            self.assertIn({'name':'access-control-allow-origin','value':'https://old.reddit.com'},headers)

    def test_redirects_errors_and_missing_responses_are_not_fabricated_as_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);url='https://example.test/image'
            self.assertIsNone(benchmark.frozen_response(root,url,'Image'))
            self.put(root,url,status='403')
            self.assertIsNone(benchmark.frozen_response(root,url,'Image'))
            self.put(root,url,final='https://redirect.test/image')
            self.assertIsNone(benchmark.frozen_response(root,url,'Image'))

    def test_runtime_pins_cover_brave_framework_and_vox_transitive_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            vox = root / 'Vox.app/Contents/MacOS/Vox'
            brave = root / 'Brave.app/Contents/MacOS/Brave Browser'
            framework = brave.parent.parent / 'Frameworks/Brave Browser Framework.framework/Versions/1/Brave Browser Framework'
            framework.parent.mkdir(parents=True)
            framework.write_bytes(b'framework code')
            dependency = root / 'transitive-native.dylib'
            helper = vox.with_name('VoxAdblockWorker')
            helper.parent.mkdir(parents=True)
            helper.write_bytes(b'helper')
            args = SimpleNamespace(vox=vox, brave=brave, html=root/'page.html',
                                   expected=root/'expected.png', network_deny=root/'deny.dylib')
            with patch('measure_sealed_github_instructions.native_dependencies', return_value=[dependency]), \
                    patch.object(benchmark, 'digest', return_value='hash'):
                paths = benchmark.pinned_inputs(args)
            self.assertIn(str(framework.resolve()), paths)
            self.assertIn(str(dependency.resolve()), paths)
            self.assertIn(str(helper.resolve()), paths)
            self.assertIn(str(benchmark.REPO / 'tools/process_instruction_counts.py'), paths)


class InstructionGateTests(unittest.TestCase):
    def pair(self,vox,brave,exact=True):
        return {'vox':dict(instructions=vox,pixels_exact=exact,exit=0),
                'brave':dict(instructions=brave,pixels_exact=True,exit=0)}

    def test_requires_worst_vox_to_beat_best_brave_by_fifteen_percent(self):
        self.assertTrue(benchmark.evaluate_pairs([self.pair(80,100),self.pair(85,110)])['passed'])
        result=benchmark.evaluate_pairs([self.pair(70,100),self.pair(86,100)])
        self.assertGreater(result['median_paired_reduction'],.15)
        self.assertFalse(result['passed'])

    def test_failed_or_absent_pixel_equality_and_zero_counters_receive_no_credit(self):
        for pairs in [[],[self.pair(50,100,False)],[self.pair(0,100)]]:
            with self.assertRaises(ValueError):benchmark.evaluate_pairs(pairs)

    def test_unknown_abnormal_and_non_integer_browser_exits_are_rejected(self):
        for exit in [None, False, -11, 1]:
            pair = self.pair(80, 100)
            pair['brave']['exit'] = exit
            with self.assertRaisesRegex(ValueError, 'successful exit'):
                benchmark.evaluate_pairs([pair])
        pair = self.pair(80, 100)
        del pair['brave']['exit']
        with self.assertRaisesRegex(ValueError, 'successful exit'):
            benchmark.evaluate_pairs([pair])
        for change in [dict(shutdown_forced=True), dict(valid=False)]:
            pair = self.pair(80, 100)
            pair['brave'].update(change)
            with self.assertRaisesRegex(ValueError, 'successful exit'):
                benchmark.evaluate_pairs([pair])

    def test_large_counter_gate_keeps_a_one_instruction_failure(self):
        self.assertTrue(benchmark.evaluate_pairs([self.pair(17 * 10**17, 20 * 10**17)])['passed'])
        self.assertFalse(benchmark.evaluate_pairs([self.pair(17 * 10**17 + 1, 20 * 10**17)])['passed'])

    def test_child_environment_is_restored_even_after_failed_capture(self):
        original=dict(DYLD_INSERT_LIBRARIES='user-library',VOX_COOKIE_FILE='user-cookies',
                      HTTPS_PROXY='proxy',LADYBIRD_ENABLE_SNAPSHOT_CACHE='1')
        with patch.dict(os.environ,original,clear=True):
            with self.assertRaisesRegex(RuntimeError,'capture failed'):
                with benchmark.native_environment(Path('/offline.dylib')):
                    self.assertEqual(os.environ['DYLD_INSERT_LIBRARIES'],'/offline.dylib')
                    self.assertEqual(os.environ['VOX_COOKIE_FILE'],'')
                    self.assertNotIn('HTTPS_PROXY',os.environ)
                    self.assertNotIn('LADYBIRD_ENABLE_SNAPSHOT_CACHE',os.environ)
                    raise RuntimeError('capture failed')
            self.assertEqual(dict(os.environ),original)

    def test_private_profiles_are_empty_distinct_and_removed_after_each_observation(self):
        with tempfile.TemporaryDirectory() as directory:
            profiles = []
            for _ in range(2):
                with benchmark.private_measurement_environment(Path('/offline.dylib'), directory) as profile:
                    self.assertEqual(list(profile.iterdir()), [])
                    self.assertEqual(os.environ['VOX_PROFILE_DIR'], str(profile))
                    self.assertEqual(os.environ['LADYBIRD_SCREENSHOT_SCALE'], '1')
                    self.assertEqual(os.environ['DYLD_INSERT_LIBRARIES'], '/offline.dylib')
                    (profile / 'settings.json').write_text('saved proxy and bookmark settings')
                    profiles.append(profile)
                self.assertFalse(profile.exists())
            self.assertNotEqual(*profiles)

    def test_private_environment_sanitizes_both_engines_and_restores_after_failure(self):
        original = dict(PATH='/bin', VOX_PROFILE_DIR='/user/profile', VOX_CAPTURE_DOCUMENT_ONLY='1',
                        HTTPS_PROXY='ambient proxy', LADYBIRD_ENABLE_SNAPSHOT_CACHE='1',
                        DYLD_INSERT_LIBRARIES='/ambient.dylib', GC_INITIAL_HEAP_SIZE='1G',
                        JSC_useJIT='false')
        with patch.dict(os.environ, original, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                with benchmark.private_measurement_environment() as profile:
                    self.assertNotEqual(str(profile), '/user/profile')
                    for key in original.keys() - {'PATH', 'VOX_PROFILE_DIR'}:
                        self.assertNotIn(key, os.environ)
                    raise RuntimeError('capture failed')
            self.assertEqual(dict(os.environ), original)


if __name__=='__main__':unittest.main()
