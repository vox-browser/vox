import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from forum_news_pixels import (CATALOG, capture_site_archive, check_filters, check_native, native_capture_environment,
                               oracle_command, seal_capture, warm_native_cache, warm_oracle_cache, write_json)
from page_archive import digest, load_archive


class ForumNewsPixelTests(unittest.TestCase):
    def test_complete_live_capture_uses_qualified_cache_without_changing_the_replay_template(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            archive = output / 'sealed'
            common = ['oracle', '--profile-template', '/original', '--extension', '/full-ubo']
            prepared = ['oracle', '--profile-template', '/closed-warmup', '--extension', '/full-ubo']
            route = ['--proxy-server', 'http://127.0.0.1:1234']
            events = []
            def warm(command, capture_route, directory, timeout):
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

    def test_all_ten_sites_are_registered_once(self):
        sites = json.loads(CATALOG.read_text())['sites']
        self.assertEqual(len(sites), 10)
        self.assertEqual(len({s['url'] for s in sites}), 10)
        self.assertEqual(len({s['id'] for s in sites}), 10)
        self.assertEqual(sites[0]['id'], 'hacker-news')
        self.assertIn('reddit', {s['id'] for s in sites})
        for site in sites:
            directory = CATALOG.parent / 'sites' / site['id']
            self.assertTrue((directory / 'manifest.json').is_file() or (directory / 'status.json').is_file(), site['id'])

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
            with self.assertRaises(FileExistsError):
                seal_capture(capture, archive, report)
            (archive / 'bodies' / entry['sha256']).write_bytes(b'changed')
            with self.assertRaises(ValueError):
                load_archive(archive)


if __name__ == '__main__':
    unittest.main()
