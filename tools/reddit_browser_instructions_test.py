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

    def test_query_urls_use_the_native_raw_request_uri_key(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);url='https://example.test/image?width=140&s=1'
            self.put(root,url+'\nAccept: '+benchmark.IMAGE_ACCEPT,b'unprefixed',final=url)
            self.assertIsNone(benchmark.frozen_response(root,url,'Image'))
            path=self.put(root,'raw-request-uri-v1\n'+url+'\nAccept: '+benchmark.IMAGE_ACCEPT,final=url)
            self.assertEqual(benchmark.frozen_response(root,url,'Image')[2],path)

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

    def test_explicit_pixel_checker_is_pinned(self):
        from types import SimpleNamespace
        args = SimpleNamespace(vox=Path('/Vox.app/Contents/MacOS/Vox'),
            brave=Path('/Brave.app/Contents/MacOS/Brave Browser'),html=Path('/page.html'),
            expected=Path('/ref.png'),network_deny=Path('/deny.dylib'),diff_tool=Path('/verified/pixel_diff'))
        with patch('measure_sealed_github_instructions.native_dependencies', return_value=[]), \
                patch.object(benchmark,'digest',return_value='hash'):
            self.assertIn(str(args.diff_tool), benchmark.pinned_inputs(args))

    def test_vox_reference_is_per_engine_pinned_and_absent_by_default(self):
        args = SimpleNamespace(vox=Path('/Vox.app/Contents/MacOS/Vox'),
            brave=Path('/Brave.app/Contents/MacOS/Brave Browser'), html=Path('/page.html'),
            expected=Path('/brave.png'), network_deny=Path('/deny.dylib'), diff_tool=Path('/pixel_diff'))
        self.assertEqual(benchmark.engine_reference(args, 'vox'), Path('/brave.png'))
        args.expected_vox = None
        self.assertEqual(benchmark.engine_reference(args, 'vox'), Path('/brave.png'))
        args.expected_vox = Path('/vox.png')
        self.assertEqual(benchmark.engine_reference(args, 'vox'), Path('/vox.png'))
        self.assertEqual(benchmark.engine_reference(args, 'brave'), Path('/brave.png'))
        with patch('measure_sealed_github_instructions.native_dependencies', return_value=[]), \
                patch.object(benchmark, 'digest', return_value='hash'):
            self.assertIn(str(Path('/vox.png').resolve()), benchmark.pinned_inputs(args))


class DocumentIdentityTests(unittest.TestCase):
    def test_both_vox_backends_are_explicit_in_the_real_launch_arguments(self):
        from measure_browser_instructions import vox_launch_command
        for engine in ['javascriptcore','libjs']:
            args=SimpleNamespace(vox_arg=benchmark.vox_launch_arguments(engine),width=1024,
                                 height=768,url='file:///frozen.html')
            command=vox_launch_command(args,Path('/Vox'),'/capture.png')
            self.assertIn('--enable-javascript',command)
            self.assertIn('--js-engine='+engine,command)
            self.assertEqual(command[-1],args.url)
        with self.assertRaisesRegex(ValueError,'not V8'):
            benchmark.vox_launch_arguments('v8')

    def test_source_title_and_post_order_are_derived_without_changing_noscript_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'page.html'
            path.write_text('<title>Programming &amp; tools</title><div class="thing link" data-fullname="t3_a"></div>'
                            '<div class="thing" data-fullname="t1_comment"></div>'
                            '<div class="thing link" data-fullname="t3_b"></div>')
            self.assertEqual(benchmark.document_identity(path),('Programming & tools',['t3_a','t3_b']))
            path.write_text('<title>Blocked</title>no listing')
            with self.assertRaisesRegex(ValueError,'post identities'):
                benchmark.document_identity(path)

    def test_both_engines_reject_missing_reordered_or_incomplete_posts(self):
        posts=['t3_a','t3_b']
        audit=dict(url='file:///frozen.html',title='programming',ready='complete',
                   viewport_width=1024,viewport_height=768,fully_active=True,paint_commands=10,
                   postIds=posts,selections=[dict(name='posts',count=2,elements=[
                       dict(attributes={'data-fullname':post}) for post in posts])])
        for engine in ['vox','brave']:
            benchmark.validate_document(dict(document_audit=audit),audit['url'],'programming',posts,engine)
            for changed in [dict(ready='loading'),dict(viewport_height=740),dict(title='Blocked'),
                            dict(postIds=list(reversed(posts)),selections=[dict(name='posts',count=0)])]:
                with self.assertRaises(RuntimeError):
                    benchmark.validate_document(dict(document_audit=dict(audit,**changed)),audit['url'],
                                                'programming',posts,engine)
        with self.assertRaisesRegex(RuntimeError,'inactive'):
            benchmark.validate_document(dict(document_audit=dict(audit,fully_active=False)),audit['url'],
                                        'programming',posts,'vox')


class InstructionGateTests(unittest.TestCase):
    def pair(self,vox,brave,exact=True):
        return {'vox':dict(instructions=vox,pixels_exact=exact,exit=0),
                'brave':dict(instructions=brave,pixels_exact=True,exit=0)}

    def test_requires_worst_vox_to_beat_best_brave_by_fifteen_percent(self):
        self.assertTrue(benchmark.evaluate_pairs([self.pair(80,100),self.pair(85,110)])['passed'])
        result=benchmark.evaluate_pairs([self.pair(70,100),self.pair(86,100)])
        self.assertGreater(result['median_paired_reduction'],.15)
        self.assertFalse(result['passed'])

    def test_vox_only_cohort_compares_medians_and_keeps_the_conservative_bound(self):
        rows=lambda *counts:[{'vox':dict(instructions=c,pixels_exact=True,exit=0)} for c in counts]
        result=benchmark.evaluate_vox_cohort(rows(88,90,95),[100,101,99],.10)
        self.assertTrue(result['passed']);self.assertFalse(result['conservative_passed'])
        self.assertAlmostEqual(result['median_reduction'],.10)
        self.assertFalse(benchmark.evaluate_vox_cohort(rows(91),[100],.10)['passed'])
        self.assertNotIn('passed',benchmark.evaluate_vox_cohort(rows(91)))
        for bad in [rows(0),[{'vox':dict(instructions=5,pixels_exact=False,exit=0)}],
                    [{'vox':dict(instructions=5,pixels_exact=True,exit=1)}],
                    [{'vox':dict(instructions=5,pixels_exact=True,exit=0),'brave':{}}]]:
            with self.assertRaises(ValueError):benchmark.evaluate_vox_cohort(bad,[100])

    def test_vox_controls_are_explicit_kill_switches(self):
        self.assertEqual(benchmark.vox_control_environment(['VOX_DISABLE_X=1']), {'VOX_DISABLE_X': '1'})
        self.assertEqual(benchmark.vox_control_environment([]), {})
        for bad in [['VOX_PROFILE_INSTRUCTIONS=1'], ['VOX_DISABLE_X'], ['VOX_DISABLE_X='],
                    ['VOX_DISABLE_X=1', 'VOX_DISABLE_X=2'], ['GC_MARKERS=1']]:
            with self.assertRaises(ValueError):benchmark.vox_control_environment(bad)

    def test_vox_only_baseline_must_share_fixture_cache_and_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'summary.json'
            path.write_text(json.dumps(dict(html_sha256='h',vox_reference_sha256='r',cache_sha256='c',
                                            pairs=[{'vox':dict(instructions=7)}])))
            self.assertEqual(benchmark.baseline_vox_counts(path,'h','r','c'),[7])
            for changed in [('x','r','c'),('h','x','c'),('h','r','x')]:
                with self.assertRaises(ValueError):benchmark.baseline_vox_counts(path,*changed)

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
