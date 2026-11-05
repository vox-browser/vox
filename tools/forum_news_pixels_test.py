import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from forum_news_pixels import (CATALOG, VOX_BUNDLED_ADBLOCK_ASSETS, VOX_RUNTIME_ASSETS, brave_identity, capture_replay_references, capture_site_archive, check_filters, check_native,
                               executable_identity, archive_animation_policy,
                               captured_focus_state,
                               native_capture_environment, oracle_command, pixel_status, run_case, seal_capture,
                               warm_native_cache, warm_oracle_cache, write_json)
from page_archive import digest, load_archive


class ForumNewsPixelTests(unittest.TestCase):
    def test_animation_policy_requires_matching_source_provenance(self):
        report = dict(oracle=dict(image_animation_policy='none'))
        self.assertEqual(archive_animation_policy({}, {}), 'allowed')
        self.assertEqual(archive_animation_policy(dict(image_animation_policy='none'), report), 'none')
        with self.assertRaisesRegex(RuntimeError, 'Source and archive'):
            archive_animation_policy(dict(image_animation_policy='none'), {})
        with self.assertRaisesRegex(RuntimeError, 'capture a new candidate'):
            archive_animation_policy({}, {}, 'none')
        with self.assertRaisesRegex(RuntimeError, 'Unsupported'):
            archive_animation_policy(dict(image_animation_policy='skip'), {})

    def test_static_capture_forwards_an_explicit_policy_to_both_browsers(self):
        args = SimpleNamespace(extension=Path('/extension'), checker=Path('/checker'),
                               brave=Path('/brave'), settle=5, profile_template=None,
                               image_animation_policy='none')
        command = oracle_command(dict(url='https://news.example/'), args)
        self.assertEqual(command[command.index('--image-animation-policy')+1], 'none')
        env = native_capture_environment(Path('/profile'), Path('/ca'), Path('/cache'),
            Path('/audit'), Path('/config'), Path('/requests'), 5, 'none')
        self.assertEqual(env['VOX_CAPTURE_IMAGE_ANIMATION_POLICY'], 'none')
        env = native_capture_environment(Path('/profile'), Path('/ca'), Path('/cache'),
            Path('/audit'), Path('/config'), Path('/requests'), 5)
        self.assertNotIn('VOX_CAPTURE_IMAGE_ANIMATION_POLICY', env)

    def test_source_focus_is_retained_as_interaction_metadata(self):
        self.assertIsNone(captured_focus_state({}))
        self.assertIsNone(captured_focus_state(dict(active_element=dict(tag='BODY',id='',focus_visible=False))))
        focus=dict(id='consent-banner',tag='DIV',focus_visible=True)
        self.assertEqual(captured_focus_state(dict(active_element=focus)),focus)
        for unsupported in [dict(id='',tag='DIV',focus_visible=True),
                            dict(id='banner',tag='DIV',focus_visible=False)]:
            with self.assertRaisesRegex(RuntimeError,'cannot be replayed exactly'):
                captured_focus_state(dict(active_element=unsupported))

    def test_native_capture_rejects_lost_focus_before_pixel_acceptance(self):
        with self.assertRaisesRegex(RuntimeError,'focus identity'):
            check_native(dict(active_element=dict(id='',tag='BODY',focus_visible=False)),
                         dict(active_element=dict(id='banner',tag='DIV',focus_visible=True)))

    def test_reference_replays_use_separate_process_commands_with_the_same_cache_template(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            common = ['node', 'oracle', '--profile-template', '/closed-cache', '--extension', '/full-ubo']
            route = ['--proxy-server', 'socks5://127.0.0.1:1234', '--replay-spki', 'pinned']
            calls = []
            def capture(command, prefix, timeout):
                calls.append(command)
                name = prefix.name
                self.assertEqual(timeout, 60)
                self.assertEqual(command, common + ['--pixel-reference', output/(name+'.png'),
                                                   '--output', output/(name+'.json'), *route])
                (output/(name+'.png')).write_bytes(name.encode())
                write_json(output/(name+'.json'), self.report())
            expected = dict(exact=False, different_pixels=1)
            with patch('forum_news_pixels.guarded', side_effect=capture), \
                    patch('forum_news_pixels.compare', return_value=expected) as compare:
                self.assertEqual(capture_replay_references(common, route, output, 60, Path('/diff')), expected)
                compare.assert_called_once_with(output/'brave.png', output/'brave-repeat.png',
                                                output/'reference-replay.diff.png', Path('/diff'))
            self.assertEqual(len(calls), 2)
            self.assertEqual(common[common.index('--profile-template')+1], '/closed-cache')
            for name in ['brave', 'brave-repeat']:
                self.assertTrue((output/(name+'.png')).is_file())
                check_filters(json.loads((output/(name+'.json')).read_text()))
            self.assertEqual(json.loads((output/'reference-replay.json').read_text()), expected)

    def test_repeated_reference_cannot_qualify_with_invalid_full_ubo_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            def capture(command, prefix, timeout):
                report = self.report()
                if prefix.name == 'brave-repeat':
                    report['cosmetic']['css_matches'] = False
                write_json(output/(prefix.name+'.json'), report)
            with patch('forum_news_pixels.guarded', side_effect=capture), \
                    patch('forum_news_pixels.compare') as compare:
                with self.assertRaisesRegex(RuntimeError, 'cosmetic'):
                    capture_replay_references(['oracle'], [], output, 60, Path('/diff'))
                compare.assert_not_called()
            self.assertFalse((output/'reference-replay.json').exists())
            self.assertFalse(json.loads((output/'brave-repeat.json').read_text())['cosmetic']['css_matches'])

    def test_a_matching_first_frame_cannot_hide_reference_variation(self):
        exact = dict(exact=True, different_pixels=0)
        different = dict(exact=False, different_pixels=1)
        self.assertEqual(pixel_status(exact, exact, different), 'reference-replay-mismatch')
        self.assertEqual(pixel_status(different, different, different), 'reference-replay-mismatch')
        self.assertEqual(pixel_status(exact, different, exact), 'live-to-frozen-mismatch')
        self.assertEqual(pixel_status(different, exact, exact), 'pixel-mismatch')
        self.assertEqual(pixel_status(exact, exact, exact), 'pass')

    def browser_inputs(self, root):
        root = root.resolve()
        vox = root / 'Vox.app/Contents/MacOS/Vox'
        brave = root / 'Brave.app/Contents/MacOS/Brave'
        framework = root / 'Brave.app/Contents/Frameworks/Brave Framework.framework'
        files = [vox, vox.parent / 'libpaint.dylib', vox.parent / 'VoxAdblockWorker', brave,
                 framework / 'Versions/1/Brave Framework',
                 framework / 'Versions/2/Brave Framework',
                 framework / 'Versions/1/Libraries/libGLESv2.dylib',
                 framework / 'Versions/1/Helpers/Renderer.app/Contents/MacOS/Renderer']
        for index, path in enumerate(files):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(bytes.fromhex('cffaedfe') + bytes([index]) * 16)
        (framework / 'Versions/Current').symlink_to('1', target_is_directory=True)
        return vox, brave, framework

    def test_brave_identity_includes_framework_gpu_library_and_renderer_helper(self):
        with tempfile.TemporaryDirectory() as temporary:
            vox, brave, framework = self.browser_inputs(Path(temporary))
            identity = brave_identity(brave)
            for path in [brave, framework / 'Versions/1/Brave Framework',
                         framework / 'Versions/1/Libraries/libGLESv2.dylib',
                         framework / 'Versions/1/Helpers/Renderer.app/Contents/MacOS/Renderer',
                         framework / 'Versions/Current/Brave Framework']:
                self.assertEqual(identity[str(path)], digest(path.read_bytes()))

    def test_vox_identity_includes_worker_and_runtime_assets_without_changing_brave_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            vox, brave, _ = self.browser_inputs(root)
            checkout = root / 'checkout'
            for name in VOX_RUNTIME_ASSETS:
                path = checkout / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(name.encode())
            with patch('forum_news_pixels.REPO', checkout):
                identity = executable_identity(vox)
                for path in [vox.parent / 'VoxAdblockWorker',
                             *(checkout / name for name in VOX_RUNTIME_ASSETS)]:
                    self.assertEqual(identity[str(path.resolve())], digest(path.read_bytes()))
                self.assertFalse(any(str(checkout) in path for path in brave_identity(brave)))

    def test_comparison_rejects_browser_input_changes_after_a_successful_capture(self):
        for changed in ['vox', 'vox-library', 'vox-helper', 'runtime-engine',
                        'runtime-metadata', 'runtime-stylesheet', 'brave-framework',
                        'brave-gpu', 'brave-helper', 'active-version']:
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                vox, brave, framework = self.browser_inputs(root)
                checkout = root / 'checkout'
                for name in VOX_RUNTIME_ASSETS:
                    path = checkout / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(name.encode())
                args = SimpleNamespace(output=root / 'output', vox=vox, brave=brave)
                def capture(site, arguments, output):
                    before = json.loads((output / 'browser-identities.json').read_text())
                    self.assertIn(str(framework / 'Versions/Current/Brave Framework'), before['brave'])
                    if changed == 'active-version':
                        current = framework / 'Versions/Current'
                        current.unlink()
                        current.symlink_to('2', target_is_directory=True)
                    else:
                        path = {'vox': vox, 'vox-library': vox.parent / 'libpaint.dylib',
                                'vox-helper': vox.parent / 'VoxAdblockWorker',
                                'runtime-engine': checkout / 'adblock/engine.js.gz',
                                'runtime-metadata': checkout / 'adblock/engine.snapshot.json.gz',
                                'runtime-stylesheet': checkout / 'css/ua_default.css',
                                'brave-framework': framework / 'Versions/1/Brave Framework',
                                'brave-gpu': framework / 'Versions/1/Libraries/libGLESv2.dylib',
                                'brave-helper': framework / 'Versions/1/Helpers/Renderer.app/Contents/MacOS/Renderer'}[changed]
                        path.write_bytes(path.read_bytes() + b'updated')
                    return dict(status='pass', different_pixels=0)
                with patch('forum_news_pixels.REPO', checkout), \
                        patch('forum_news_pixels.capture_case', side_effect=capture):
                    with self.assertRaisesRegex(RuntimeError, 'Browser inputs changed'):
                        run_case(dict(id='news'), args)
                after = json.loads((args.output / 'news/browser-identities-after.json').read_text())
                before = json.loads((args.output / 'news/browser-identities.json').read_text())
                self.assertNotEqual(before, after)

    def test_packaged_filter_inputs_replace_unused_checkout_copies_in_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            vox, _, _ = self.browser_inputs(root)
            checkout = root / 'checkout'
            resources = vox.parent.parent / 'Resources'
            resources.mkdir()
            for source, packaged in VOX_BUNDLED_ADBLOCK_ASSETS.items():
                path = checkout / source
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'checkout')
                (resources / packaged).write_bytes(packaged.encode())
            with patch('forum_news_pixels.REPO', checkout):
                before = executable_identity(vox)
                for source, packaged in VOX_BUNDLED_ADBLOCK_ASSETS.items():
                    self.assertNotIn(str((checkout / source).resolve()), before)
                    self.assertEqual(before[str(resources / packaged)], digest(packaged.encode()))
                    (checkout / source).write_bytes(b'new unrelated checkout version')
                self.assertEqual(before, executable_identity(vox))
                for packaged in VOX_BUNDLED_ADBLOCK_ASSETS.values():
                    with self.subTest(packaged=packaged):
                        path = resources / packaged
                        original = path.read_bytes()
                        path.write_bytes(b'changed packaged input')
                        self.assertNotEqual(before, executable_identity(vox))
                        path.write_bytes(original)

    def test_comparison_retains_both_browser_identities_for_an_unchanged_capture(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            vox, brave, framework = self.browser_inputs(root)
            args = SimpleNamespace(output=root / 'output', vox=vox, brave=brave)
            expected = dict(status='pass', different_pixels=0)
            with patch('forum_news_pixels.capture_case', return_value=expected):
                self.assertEqual(run_case(dict(id='news'), args), expected)
            output = args.output / 'news'
            before = json.loads((output / 'browser-identities.json').read_text())
            self.assertEqual(before, json.loads((output / 'browser-identities-after.json').read_text()))
            self.assertIn(str(vox.parent / 'libpaint.dylib'), before['vox'])

    def test_failed_capture_retains_final_browser_identities_and_its_original_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            vox, brave, framework = self.browser_inputs(root)
            args = SimpleNamespace(output=root / 'output', vox=vox, brave=brave)
            with patch('forum_news_pixels.capture_case', side_effect=RuntimeError('not ready')):
                with self.assertRaisesRegex(RuntimeError, 'not ready'):
                    run_case(dict(id='news'), args)
            output = args.output / 'news'
            self.assertEqual(json.loads((output / 'browser-identities.json').read_text()),
                             json.loads((output / 'browser-identities-after.json').read_text()))

    def test_complete_live_capture_uses_qualified_cache_without_changing_the_replay_template(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            archive = output / 'sealed'
            common = ['oracle', '--profile-template', '/original', '--extension', '/full-ubo']
            prepared = ['oracle', '--profile-template', '/closed-warmup', '--extension', '/full-ubo']
            route = ['--proxy-server', 'http://127.0.0.1:1234']
            events = []
            def warm(command, capture_route, directory, timeout, *, capture_archive=False):

                self.assertTrue(capture_archive)
                self.assertEqual(command, common)
                self.assertEqual(capture_route, route)
                self.assertTrue(directory.is_dir())
                events.append('warm')
                return prepared
            def capture(command, prefix, timeout):
                self.assertEqual(command, prepared + route + ['--capture-dir', output/'capture',
                                                              '--output', output/'capture.json'])
                events.append('capture')
            with patch('forum_news_pixels.warm_oracle_cache', side_effect=warm), \
                    patch('forum_news_pixels.guarded', side_effect=capture), \
                    patch('forum_news_pixels.seal_capture') as seal:
                capture_site_archive(common, route, output, archive, 60, 'complete')
            self.assertEqual(events, ['warm', 'capture'])
            self.assertEqual(common[2], '/original')
            self.assertTrue(json.loads((output/'capture-cache-policy.json').read_text())['warmup_qualified'])
            seal.assert_called_once_with(output/'capture', archive, output/'capture.json')

    def test_cold_live_capture_does_not_add_cache_warmup(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            common = ['oracle', '--extension', '/full-ubo']
            with patch('forum_news_pixels.warm_oracle_cache') as warm, \
                    patch('forum_news_pixels.guarded') as capture, \
                    patch('forum_news_pixels.seal_capture'):
                capture_site_archive(common, [], output, output/'sealed', 60, 'cold')
            warm.assert_not_called()
            self.assertEqual(capture.call_args.args[0][:len(common)], common)
            self.assertFalse(json.loads((output/'capture-cache-policy.json').read_text())['warmup_qualified'])

    def test_failed_live_cache_warmup_cannot_capture_or_replace_a_fixture(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            with patch('forum_news_pixels.warm_oracle_cache', side_effect=RuntimeError('not ready')), \
                    patch('forum_news_pixels.guarded') as capture, \
                    patch('forum_news_pixels.seal_capture') as seal:
                with self.assertRaisesRegex(RuntimeError, 'not ready'):
                    capture_site_archive(['oracle'], [], output, output/'sealed', 60, 'complete')
            capture.assert_not_called()
            seal.assert_not_called()
            self.assertFalse(json.loads((output/'capture-cache-policy.json').read_text())['warmup_qualified'])

    def test_oracle_warmup_replaces_only_the_disposable_profile_template(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            common = ['node', 'oracle.mjs', '--url', 'https://news.example/',
                      '--profile-template', '/closed-template', '--extension', '/full-ubo']
            route = ['--proxy-server', 'socks5://127.0.0.1:1234', '--replay-spki', 'private-ca']
            def capture(command, prefix, timeout):
                self.assertEqual(command[:len(common)], common)
                self.assertEqual(command[len(common):len(common)+len(route)], route)
                Path(command[command.index('--profile-output')+1]).mkdir()
                write_json(Path(command[command.index('--output')+1]), self.report())
            with patch('forum_news_pixels.guarded', side_effect=capture):
                prepared = warm_oracle_cache(common, route, output, 60)
            self.assertEqual(common[common.index('--profile-template')+1], '/closed-template')
            self.assertEqual(prepared[prepared.index('--profile-template')+1], str(output/'brave-warm-profile'))
            self.assertEqual(prepared[prepared.index('--extension')+1], '/full-ubo')

    def test_oracle_warmup_rejects_filter_disagreement_and_missing_closed_profile(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            def capture(command, prefix, timeout):
                write_json(output/'brave-warm.json', self.report())
            with patch('forum_news_pixels.guarded', side_effect=capture):
                with self.assertRaisesRegex(RuntimeError, 'closed profile'):
                    warm_oracle_cache(['oracle'], [], output, 60)
            report = self.report()
            report['cosmetic']['css_matches'] = False
            with patch('forum_news_pixels.guarded'), patch('forum_news_pixels.read_json', return_value=report):
                with self.assertRaisesRegex(RuntimeError, 'cosmetic'):
                    warm_oracle_cache(['oracle'], [], output, 60)

    def test_live_cache_preparation_retains_response_provenance_for_cached_headers(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            common = ['oracle', '--url', 'https://news.example/']
            def capture(command, prefix, timeout):
                self.assertEqual(Path(command[command.index('--cache-preparation-dir') + 1]), output / 'capture')
                Path(command[command.index('--profile-output') + 1]).mkdir()
                write_json(output / 'brave-warm.json', self.report())
            with patch('forum_news_pixels.guarded', side_effect=capture):
                prepared = warm_oracle_cache(common, [], output, 60, capture_archive=True)
            self.assertEqual(prepared[prepared.index('--cached-response-headers') + 1], str(output / 'capture'))
            self.assertEqual(common, ['oracle', '--url', 'https://news.example/'])
    def test_complete_cache_uses_a_discarded_process_with_separate_profile_and_audit(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            profile = output / 'profile'
            profile.mkdir()
            settings = dict(enabled=True, host='127.0.0.1', port='1234')
            write_json(profile / 'settings.json', settings)
            reference = dict(url='https://news.example/', title='News')
            audit = dict(**reference, ready='complete', viewport_width=1024, viewport_height=768,
                         selections=[dict(name='body', elements=[dict(text='story ' * 300)])])
            environment = dict(VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(output / 'cache'),
                               VOX_CAPTURE_AUDIT_PATH=str(output / 'main.audit.json'))
            def capture(command, prefix, timeout, env):
                self.assertEqual(command[-1], reference['url'])
                self.assertEqual(env['LADYBIRD_CACHE_DIR'], environment['LADYBIRD_CACHE_DIR'])
                self.assertNotEqual(env['VOX_PROFILE_DIR'], str(profile))
                write_json(Path(env['VOX_CAPTURE_AUDIT_PATH']), audit)
            with patch('forum_news_pixels.guarded', side_effect=capture) as launch, \
                    patch('forum_news_pixels.executable_identity', return_value={'binary': 'same'}):
                warm_native_cache(Path('/vox'), reference['url'], output, profile, environment,
                                  reference, 60, {'binary': 'same'})
            self.assertEqual(launch.call_count, 1)
            self.assertEqual(json.loads((output / 'vox-warm-profile/settings.json').read_text()), settings)
            self.assertFalse((output / 'main.audit.json').exists())
            self.assertEqual(environment['VOX_PROFILE_DIR'], str(profile))

    def test_cache_warmup_cannot_qualify_a_navigation_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            profile = output / 'profile'
            profile.mkdir()
            write_json(profile / 'settings.json', {})
            def capture(command, prefix, timeout, env):
                write_json(Path(env['VOX_CAPTURE_AUDIT_PATH']), dict(url='about:blank', title='Error'))
            with patch('forum_news_pixels.guarded', side_effect=capture), \
                    patch('forum_news_pixels.executable_identity', return_value={'binary': 'same'}):
                with self.assertRaises(RuntimeError):
                    warm_native_cache(Path('/vox'), 'https://news.example/', output, profile, {},
                                      dict(url='https://news.example/', title='News'), 60, {'binary': 'same'})

    def test_cache_warmup_rejects_a_changed_executable(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            profile = output / 'profile'
            profile.mkdir()
            write_json(profile / 'settings.json', {})
            with patch('forum_news_pixels.guarded'), \
                    patch('forum_news_pixels.executable_identity', return_value={'binary': 'changed'}):
                with self.assertRaisesRegex(RuntimeError, 'bundle changed during cache warmup'):
                    warm_native_cache(Path('/vox'), 'https://news.example/', output, profile, {},
                                      dict(url='https://news.example/', title='News'), 60, {'binary': 'same'})

    def test_native_capture_preserves_reference_consent_ui_in_an_isolated_environment(self):
        with patch.dict('os.environ', {'PATH': '/tools', 'VOX_BLOCK_COOKIE_BANNERS': '1',
                                      'VOX_PROFILE_DIR': '/personal-profile',
                                      'HTTPS_PROXY': 'http://unrelated.invalid',
                                      'DYLD_INSERT_LIBRARIES': '/unrelated.dylib'}, clear=True):
            environment = native_capture_environment(Path('/capture/profile'), Path('/capture/ca.pem'),
                Path('/capture/cache'), Path('/capture/audit.json'), Path('/capture/config.json'),
                Path('/capture/requests.jsonl'), 5)
        self.assertEqual(environment['VOX_BLOCK_COOKIE_BANNERS'], '0')
        self.assertEqual(environment['VOX_PROFILE_DIR'], '/capture/profile')
        self.assertEqual(environment['SSL_CERT_FILE'], '/capture/ca.pem')
        self.assertEqual(environment['VOX_ADBLOCK_LOG'], '/capture/requests.jsonl')
        self.assertEqual(environment['PATH'], '/tools')
        self.assertNotIn('HTTPS_PROXY', environment)
        self.assertNotIn('DYLD_INSERT_LIBRARIES', environment)

    def test_closed_oracle_template_is_forwarded_without_changing_filter_inputs(self):
        args = SimpleNamespace(extension=Path('/extension'), checker=Path('/checker'),
                               brave=Path('/brave'), settle=5, profile_template=None)
        site = dict(url='https://news.example/')
        fresh = oracle_command(site, args)
        self.assertNotIn('--profile-template', fresh)
        args.profile_template = Path('/closed-profile')
        prepared = oracle_command(site, args)
        self.assertEqual(prepared, fresh + ['--profile-template', '/closed-profile'])
        self.assertEqual(prepared[prepared.index('--extension') + 1], '/extension')
        self.assertEqual(prepared[prepared.index('--checker') + 1], '/checker')

    def report(self):
        return dict(counts=dict(requests=1, blocked=0, allowed=1, mismatches=0, oracle_disagreements=0),
                    requests=[dict(actual=dict(blocked=False, exception=False),
                                   expected=dict(blocked=False, exception=False))],
                    navigation=dict(coverage='page', url='https://news.example/'),
                    common_stream=dict(matches=True),
                    cosmetic=dict(css_matches=True, procedural_matches=True, scriptlet_filters_match=True))

    def test_all_sixteen_sites_are_registered_once(self):
        sites = json.loads(CATALOG.read_text())['sites']
        expected = {'hacker-news', 'reddit', 'lobsters', 'slashdot', 'stackoverflow',
                    'bbc', 'cnn', 'guardian', 'theverge', 'pikabu',
                    'techcrunch', 'engadget', 'theregister', 'slate', 'wired', 'discord'}
        self.assertEqual(len(sites), len(expected))
        self.assertEqual(len({s['url'] for s in sites}), len(expected))
        self.assertEqual({s['id'] for s in sites}, expected)
        self.assertEqual(sites[0]['id'], 'hacker-news')
        self.assertIn('reddit', {s['id'] for s in sites})
        for site in sites:
            directory = CATALOG.parent / 'sites' / site['id']
            self.assertTrue((directory / 'manifest.json').is_file() or (directory / 'status.json').is_file(), site['id'])

    def test_five_news_additions_have_sealed_full_ubo_guest_pages(self):
        for site in ['techcrunch', 'engadget', 'theregister', 'slate', 'wired']:
            with self.subTest(site=site):
                directory = CATALOG.parent / 'sites' / site
                manifest = load_archive(directory)
                self.assertEqual(digest((directory / 'live.png').read_bytes()), manifest['live_png_sha256'])
                report = directory / 'capture.json'
                self.assertEqual(digest(report.read_bytes()), manifest['capture_report_sha256'])
                check_filters(json.loads(report.read_text()))
                self.assertIn(manifest['url'], manifest['responses'])

    def test_challenges_and_incomplete_filter_evidence_cannot_pass(self):
        check_filters(self.report())
        for coverage in ['challenge', 'error', 'consent', 'empty', 'unexpected-origin']:
            report = self.report()
            report['navigation']['coverage'] = coverage
            with self.assertRaises(RuntimeError):
                check_filters(report)
        for key in ['css_matches', 'procedural_matches', 'scriptlet_filters_match']:
            report = self.report()
            report['cosmetic'][key] = False
            with self.assertRaises(RuntimeError):
                check_filters(report)
        report = self.report()
        report['requests'][0]['actual']['error'] = 'engine failure'
        with self.assertRaises(RuntimeError):
            check_filters(report, document=False)
        for requests in [[], [dict(actual=dict(blocked=False, exception=False))]]:
            report = self.report()
            report['requests'] = requests
            with self.assertRaises(RuntimeError):
                check_filters(report)

    def test_native_error_page_wrong_document_and_wrong_viewport_are_rejected(self):
        reference = dict(url='https://news.example/', title='News')
        audit = dict(**reference, ready='complete', viewport_width=1024, viewport_height=768,
                     selections=[dict(name='body', elements=[dict(text='story ' * 300)])])
        check_native(audit, reference)
        for change in [dict(title='Access denied'), dict(url='about:blank'), dict(ready='loading'),
                       dict(viewport_width=800), dict(selections=[])]:
            with self.assertRaises(RuntimeError):
                check_native(dict(audit, **change), reference)

    def test_sealed_fixture_uses_only_captured_bytes_and_retains_filter_provenance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, archive = root / 'capture', root / 'archive'
            (capture / 'cache/resources').mkdir(parents=True)
            url = 'https://news.example/'
            html = b'<!doctype html><title>News</title><p>Frozen story</p>'
            (capture / 'frozen.html').write_bytes(html)
            (capture / 'live.png').write_bytes(b'captured PNG bytes')
            source = capture / 'cache/resources' / digest(url.encode())
            source.write_bytes(html)
            write_json(Path(str(source) + '.headers.json'), [dict(name='Content-Type', value='text/html;charset=windows-1251'),
                       dict(name='Content-Security-Policy', value="default-src 'self'")])
            write_json(capture / 'archive.json', dict(url=url, document_request_method='POST', frozen_html_sha256=digest(html), resources=[
                dict(url=url, sha256=digest(b'original scripted document')),
                dict(url=url + 'missing.png', error='body unavailable')]))
            report = root / 'report.json'
            write_json(report, self.report())
            seal_capture(capture, archive, report)
            manifest = load_archive(archive)
            self.assertEqual(manifest['source_document_request_method'], 'POST')
            self.assertEqual(set(manifest['responses']), {url})
            entry = manifest['responses'][url]
            self.assertEqual((archive / 'bodies' / entry['sha256']).read_bytes(), html)
            self.assertIn(dict(name='Content-Type', value='text/html;charset=utf-8'), entry['headers'])
            self.assertIn(dict(name='Content-Security-Policy', value="default-src 'self'"), entry['headers'])
            self.assertEqual(manifest['capture_report_sha256'], digest((archive / 'capture.json').read_bytes()))
            self.assertEqual(manifest['live_png_sha256'], digest((archive / 'live.png').read_bytes()))
            static_report = self.report()
            static_report['oracle'] = dict(image_animation_policy='none')
            write_json(report, static_report)
            static_archive = root / 'static-archive'
            seal_capture(capture, static_archive, report)
            static_manifest = load_archive(static_archive)
            self.assertEqual(static_manifest['image_animation_policy'], 'none')
            self.assertEqual(archive_animation_policy(static_manifest, static_report), 'none')
            self.assertEqual((static_archive / 'bodies' / entry['sha256']).read_bytes(), html)
            with self.assertRaises(FileExistsError):
                seal_capture(capture, archive, report)
            (archive / 'bodies' / entry['sha256']).write_bytes(b'changed')
            with self.assertRaises(ValueError):
                load_archive(archive)


if __name__ == '__main__':
    unittest.main()
