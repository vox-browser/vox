from pathlib import Path
from dataclasses import dataclass
from unittest.mock import Mock, patch
import plistlib
import tempfile
import unittest
from urllib.error import HTTPError
import urllib.request

from hacker_news_browser_instructions import (
    ASSETS, WIDTH, HEIGHT, METAL_COMPILER, SET_STORE_UPDATER, accepted_coalition_executable,
    check_content, code_sign_clone_identity, document_comments, evaluate_pairs,
    exact_coalition_membership, fixture_server, membership, launch_instruction_interval,
    parse_args, progress_record, finish_capture_readiness,
    prepare_browser_profile,
    configure_brave_viewport, capture_ownership_audit, await_exit,
)


def observation(lower, upper=None, **changes):
    return dict(exit=0, pixels_exact=True, content_exact=True,
                instruction_interval=dict(lower=lower, upper=lower if upper is None else upper),
                **changes)


class HackerNewsInstructionGateTests(unittest.TestCase):
    def capture_scan(self, started=5, exited=2):
        snapshot = dict(coalition_id=10, tasks_started=started, tasks_exited=exited,
                        instructions=900)
        return dict(stable=True, all_owned=True, exact_live_count=True,
                    root_present=True, ownership_stable=True,
                    before_snapshot=dict(snapshot), after_snapshot=dict(snapshot),
                    after_ownership_snapshot=dict(snapshot))

    def capture_endpoint(self):
        return dict(label='capture_document_encoded', coalition_id=10,
                    tasks_started=5, tasks_exited=2, instructions=1000)

    def test_capture_ownership_preserves_cumulative_endpoint_and_counts_exited_tasks(self):
        endpoint = self.capture_endpoint()
        scan = self.capture_scan()
        result = capture_ownership_audit([self.capture_scan(2, 1), scan], endpoint)
        self.assertTrue(result['passed'])
        self.assertIs(result['scan'], scan)
        self.assertEqual(result['endpoint']['instructions'], 1000)
        self.assertEqual(result['endpoint']['tasks_exited'], 2)
        self.assertEqual(endpoint, self.capture_endpoint())

    def test_early_ownership_scan_cannot_certify_later_helpers(self):
        with self.assertRaisesRegex(RuntimeError, 'No stable owned Vox task set'):
            capture_ownership_audit([self.capture_scan(2, 1)], self.capture_endpoint())

    def test_capture_ownership_requires_every_live_ownership_check(self):
        for key in ['stable', 'all_owned', 'exact_live_count', 'root_present', 'ownership_stable']:
            with self.subTest(key=key):
                scan = self.capture_scan()
                scan[key] = False
                with self.assertRaises(RuntimeError):
                    capture_ownership_audit([scan], self.capture_endpoint())

    def test_capture_ownership_rejects_identity_changes_and_scan_churn(self):
        for phase in ['before_snapshot', 'after_snapshot', 'after_ownership_snapshot']:
            for key in ['coalition_id', 'tasks_started', 'tasks_exited']:
                with self.subTest(phase=phase, key=key):
                    scan = self.capture_scan()
                    scan[phase][key] += 1
                    with self.assertRaises(RuntimeError):
                        capture_ownership_audit([scan], self.capture_endpoint())

    def test_capture_ownership_rejects_missing_or_non_native_endpoints(self):
        for endpoint in [{}, dict(self.capture_endpoint(), label='navigation_started'),
                         dict(self.capture_endpoint(), tasks_started=2, tasks_exited=2),
                         dict(self.capture_endpoint(), coalition_id=True)]:
            with self.subTest(endpoint=endpoint), self.assertRaises(RuntimeError):
                capture_ownership_audit([self.capture_scan()], endpoint)

    def test_exit_observer_keeps_the_kernel_status_and_samples_only_while_live(self):
        event = Mock(fflags=1 | 0x04000000, data=0)
        queue, observe = Mock(), Mock()
        queue.control.side_effect = [[], [], [event]]
        with patch('hacker_news_browser_instructions.select.KQ_NOTE_EXIT', 1, create=True):
            self.assertEqual(await_exit(queue, float('inf'), observe), 0)
            self.assertEqual(observe.call_count, 2)
            queue.control.side_effect = [[event]]
            observe.reset_mock()
            self.assertEqual(await_exit(queue, float('inf'), observe), 0)
            observe.assert_not_called()

    def test_exit_observer_rejects_unknown_status_and_obeys_deadline(self):
        queue = Mock()
        queue.control.return_value = [Mock(fflags=0, data=0)]
        with patch('hacker_news_browser_instructions.select.KQ_NOTE_EXIT', 1, create=True), \
                self.assertRaisesRegex(RuntimeError, 'Kernel did not supply exit status'):
            await_exit(queue, float('inf'), Mock())
        queue.control.return_value = []
        observer = Mock()
        with self.assertRaisesRegex(RuntimeError, 'watchdog expired'):
            await_exit(queue, 0, observer)
        observer.assert_not_called()

    def test_explicit_emulated_capture_scale_does_not_change_native_viewport_default(self):
        from types import SimpleNamespace
        browser, client = Mock(), Mock()
        args = SimpleNamespace(scale=1, brave_emulated_viewport=True)
        result = configure_brave_viewport(browser, client, 'target', args)
        self.assertTrue(result['emulated'])
        client.call.assert_called_once_with('Emulation.setDeviceMetricsOverride',
            dict(width=1024, height=768, deviceScaleFactor=1, mobile=False))
        with patch('hacker_news_browser_instructions.resize_native_viewport', return_value={'scale': 2}) as resize:
            self.assertEqual(configure_brave_viewport(browser, client, 'target', SimpleNamespace(scale=2)), {'scale': 2})
            resize.assert_called_once_with(browser, client, 'target', 1024, 768, 2)

    def test_private_templates_preserve_inputs_and_omit_stale_browser_locks(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, profile, cache, encoded = [root / name for name in
                                               ('source', 'profile', 'cache', 'encoded')]
            for folder in (source, profile, cache, encoded):
                folder.mkdir()
            (source / 'Preferences').write_text('prepared filters')
            (source / 'DevToolsActivePort').write_text('stale endpoint')
            (source / 'SingletonLock').symlink_to('missing lock')
            (source / 'RunningChromeVersion').symlink_to('156.1.98.60')
            (encoded / 'response').write_bytes(b'original encoded response')
            args = SimpleNamespace(brave_profile_template=source, brave_cache_template=encoded)
            prepare_browser_profile('brave', profile, cache, args)
            self.assertEqual((cache / 'response').read_bytes(), (encoded / 'response').read_bytes())
            self.assertFalse((profile / 'DevToolsActivePort').exists())
            self.assertFalse((profile / 'SingletonLock').is_symlink())
            self.assertTrue((profile / 'RunningChromeVersion').is_symlink())
            (profile / 'Preferences').write_text('private change')
            self.assertEqual((source / 'Preferences').read_text(), 'prepared filters')
            prepare_browser_profile('vox', profile, cache, SimpleNamespace())

    def test_asynchronous_readiness_is_optional_and_rejects_decode_failures(self):
        from types import SimpleNamespace
        client = Mock()
        finish_capture_readiness(client, SimpleNamespace())
        client.call.assert_not_called()
        args = SimpleNamespace(post_readiness_expression='decode-visible-images')
        client.call.return_value = {'result': {'value': True}}
        finish_capture_readiness(client, args)
        client.call.assert_called_once_with('Runtime.evaluate', dict(
            expression=args.post_readiness_expression, awaitPromise=True, returnByValue=True))
        for result in [{'result': {'value': False}}, {'result': {}},
                       {'exceptionDetails': {'text': 'decode failed'}, 'result': {'value': True}}]:
            client.call.return_value = result
            with self.subTest(result=result), self.assertRaises(RuntimeError):
                finish_capture_readiness(client, args)

    def pairs(self, vox=900, brave=1000):
        return [dict(vox=observation(vox), brave=observation(brave)) for _ in range(2)]

    def test_ten_percent_reduction_is_inclusive(self):
        self.assertTrue(evaluate_pairs(self.pairs())['passed'])
        self.assertFalse(evaluate_pairs(self.pairs(vox=901))['passed'])
        self.assertTrue(evaluate_pairs(self.pairs(vox=100))['passed'])

    def test_cli_defaults_count_startup_and_use_requested_ten_percent_target(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'evidence'
            for fixture in ([], ['--home-archive', 'Tests/Browser/Brave/hn-home-instructions']):
                args = parse_args(['--output', str(output), *fixture])
                self.assertEqual(args.instruction_scope, 'launch')
                self.assertEqual(args.target_vox_fraction, .9)
                self.assertFalse(output.exists(), 'Argument parsing must not launch or write evidence')
        pairs = self.pairs(vox=3000, brave=1000)
        for pair in pairs:
            pair['vox']['launch_instruction_interval'] = dict(lower=4900, upper=4900)
            pair['brave']['launch_instruction_interval'] = dict(lower=8500, upper=8510)
        # The old headline showed 3x by subtracting unequal amounts of setup.
        # The default must gate the cumulative totals, while retaining the diagnostic.
        self.assertTrue(evaluate_pairs(pairs, args.target_vox_fraction, args.instruction_scope)['passed'])
        self.assertFalse(evaluate_pairs(pairs, args.target_vox_fraction, 'navigation')['passed'])

    def test_cli_preserves_explicit_historical_scope_and_target(self):
        args = parse_args(['--output', 'unused', '--instruction-scope', 'navigation',
                           '--target-vox-fraction', '.8'])
        self.assertEqual(args.instruction_scope, 'navigation')
        self.assertEqual(args.target_vox_fraction, .8)

    def test_progress_reports_the_selected_interval_and_retains_both(self):
        row = observation(3000, launch_instruction_interval=dict(lower=4900, upper=4900))
        for scope, key in [('launch', 'launch_instruction_interval'), ('navigation', 'instruction_interval')]:
            progress = progress_record(1, 'vox', row, scope)
            self.assertEqual(progress['instruction_scope'], scope)
            self.assertEqual(progress['instructions'], row[key])
            self.assertEqual(progress['navigation_instruction_interval'], row['instruction_interval'])
            self.assertEqual(progress['launch_instruction_interval'], row['launch_instruction_interval'])
        failed = progress_record(1, 'vox', dict(exit=1, error='launch failed'), 'launch')
        self.assertIsNone(failed['instructions'])
        self.assertEqual(failed['error'], 'launch failed')
        with self.assertRaisesRegex(RuntimeError, 'Unknown instruction scope'):
            progress_record(1, 'vox', row, 'other')

    def test_launch_totals_retain_startup_and_native_capture_boundary(self):
        result = dict(resource_coalition=17, native_coalition_markers=dict(markers=[
            dict(label='navigation_started', coalition_id=17, instructions=200),
            dict(label='capture_document_encoded', coalition_id=17, instructions=900)]))
        self.assertEqual(launch_instruction_interval('vox', result), dict(lower=900, upper=900))
        result = dict(resource_coalition=18, boundary_brackets=[
            dict(coalition_id=18, instructions=value) for value in (300, 310, 1000, 1020)])
        self.assertEqual(launch_instruction_interval('brave', result), dict(lower=1000, upper=1020))
        result['boundary_brackets'][-1]['coalition_id'] = 19
        with self.assertRaisesRegex(RuntimeError, 'coalition identity'):
            launch_instruction_interval('brave', result)

    def test_launch_totals_reject_missing_or_invalid_endpoint_readings(self):
        for readings in [[], [dict(coalition_id=1, instructions=1)],
                         [dict(coalition_id=1, instructions=2), dict(coalition_id=1, instructions=1)],
                         [dict(coalition_id=1, instructions=0), dict(coalition_id=1, instructions=1)]]:
            with self.assertRaises(RuntimeError):
                launch_instruction_interval('brave', dict(resource_coalition=1, boundary_brackets=readings))
        with self.assertRaisesRegex(RuntimeError, 'PNG endpoint'):
            launch_instruction_interval('vox', dict(resource_coalition=1,
                native_coalition_markers=dict(markers=[dict(label='navigation_started')])) )

    def test_launch_and_navigation_gates_remain_independent(self):
        pairs = self.pairs(vox=1500, brave=1000)
        for pair in pairs:
            pair['vox']['launch_instruction_interval'] = dict(lower=1800, upper=1800)
            pair['brave']['launch_instruction_interval'] = dict(lower=2100, upper=2110)
        self.assertFalse(evaluate_pairs(pairs)['passed'])
        self.assertTrue(evaluate_pairs(pairs, instruction_scope='launch')['passed'])
        pairs[0]['vox']['launch_instruction_interval']['upper'] = 1891
        self.assertFalse(evaluate_pairs(pairs, instruction_scope='launch')['passed'])
        pairs[0]['vox']['pixels_exact'] = False
        with self.assertRaisesRegex(RuntimeError, 'Every observation'):
            evaluate_pairs(pairs, instruction_scope='launch')
        with self.assertRaisesRegex(RuntimeError, 'Unknown instruction scope'):
            evaluate_pairs(pairs, instruction_scope='other')

    def test_twenty_percent_target_uses_exact_integer_bounds(self):
        self.assertTrue(evaluate_pairs(self.pairs(vox=800), .8)['passed'])
        self.assertFalse(evaluate_pairs(self.pairs(vox=801), .8)['passed'])
        pairs = self.pairs(vox=790)
        pairs[0]['vox'] = observation(790, 801)
        self.assertFalse(evaluate_pairs(pairs, .8)['passed'])
        # Large hardware counts must not lose a one-instruction failure to
        # floating-point multiplication or rounded printed percentages.
        self.assertFalse(evaluate_pairs(self.pairs(vox=8 * 10**17 + 1,
                                                  brave=10**18), .8)['passed'])

    def test_home_archive_retains_original_scripts_and_all_stories_without_refetching(self):
        from hacker_news_browser_instructions import REPO
        from page_archive import load_archive
        archive = REPO / 'Tests/Browser/Brave/hn-home-instructions'
        manifest = load_archive(archive)
        document = archive / 'bodies' / manifest['responses'][manifest['url']]['sha256']
        self.assertEqual(manifest['url'], 'https://news.ycombinator.com/')
        self.assertEqual(len(document_comments(document, 'athing')), 30)
        self.assertIn('<script', document.read_text())
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with tempfile.TemporaryDirectory() as directory:
            with fixture_server(document, Path(directory), archive) as url:
                for original, entry in manifest['responses'].items():
                    route = original.removeprefix(manifest['url'])
                    with opener.open(url + route) as response:
                        self.assertEqual(response.read(), (archive / 'bodies' / entry['sha256']).read_bytes())
                with self.assertRaises(HTTPError):
                    opener.open(url + 'not-in-archive')
        ids = document_comments(document, 'athing')
        audit = dict(url='http://fixture/', ready='complete', viewport_width=WIDTH,
                     viewport_height=HEIGHT, selections=[dict(name='stories', count=30,
                     elements=[dict(attributes=dict(id=value)) for value in ids])])
        check_content(audit, 'http://fixture/', ids, 'stories')
        audit['selections'][0]['elements'].reverse()
        with self.assertRaisesRegex(RuntimeError, 'story rows'):
            check_content(audit, 'http://fixture/', ids, 'stories')

    def test_uses_vox_upper_and_brave_lower_across_all_trials(self):
        pairs = self.pairs()
        pairs[0]['vox'] = observation(890, 910)
        pairs[0]['brave'] = observation(1000, 2000)
        pairs[1]['brave'] = observation(1090, 3000)
        result = evaluate_pairs(pairs)
        self.assertFalse(result['passed'])
        self.assertAlmostEqual(result['worst_vox_over_best_brave'], .91)

    def test_pixel_mismatch_or_failed_attempt_cannot_receive_performance_credit(self):
        for field, value in [('exit', 1), ('exit', False), ('pixels_exact', False),
                             ('content_exact', False)]:
            pairs = self.pairs(vox=1)
            pairs[0]['vox'][field] = value
            with self.assertRaisesRegex(RuntimeError, 'Every observation'):
                evaluate_pairs(pairs)

    def test_missing_pairs_and_invalid_counters_fail_closed(self):
        for pairs in [[], self.pairs()[:1], [dict(vox=observation(1)), self.pairs()[0]]]:
            with self.assertRaises(RuntimeError):
                evaluate_pairs(pairs)
        for lower, upper in [(0, 1), (-1, 1), (2, 1), (1.0, 2), (True, 2)]:
            pairs = self.pairs()
            pairs[0]['vox'] = observation(lower, upper)
            with self.assertRaisesRegex(RuntimeError, 'instruction interval'):
                evaluate_pairs(pairs)

    def test_only_private_browser_and_exact_system_service_paths_are_accepted(self):
        app = Path('/private/fixture/Brave.app')
        self.assertTrue(accepted_coalition_executable(app / 'Contents/MacOS/Brave', app))
        self.assertTrue(accepted_coalition_executable(METAL_COMPILER, app))
        self.assertTrue(accepted_coalition_executable(SET_STORE_UPDATER, app))
        for path in [Path('/Applications/Brave.app/Contents/MacOS/Brave'),
                     app / 'Contents/../../other', Path(str(METAL_COMPILER) + '-other'),
                     Path(str(SET_STORE_UPDATER) + '-other')]:
            self.assertFalse(accepted_coalition_executable(path, app))

    def test_cascadesets_service_is_counted_in_exact_live_coalition_membership(self):
        import os
        import time
        @dataclass
        class Reading:
            tasks_started: int = 2
            tasks_exited: int = 0
            instructions: int = 12345
        api = Mock()
        api.read.return_value = Reading()
        api.resource_coalition.return_value = 10
        app = Path('/private/fixture/Brave.app')
        paths = {1: str(app / 'Contents/MacOS/Brave'), 2: str(SET_STORE_UPDATER)}
        process_api = Mock()
        process_api.path.side_effect = lambda pid: paths[pid]
        rows = [dict(pid=pid, uid=os.getuid(), command=path) for pid, path in paths.items()]
        with patch('hacker_news_browser_instructions.processes', return_value=rows):
            scan = exact_coalition_membership(api, process_api, 10, app, 1, time.monotonic(), [])
            self.assertEqual(len(scan['members']), 2)
            self.assertEqual(scan['after_snapshot']['instructions'], 12345)
            paths[2] += '-other'
            with self.assertRaisesRegex(RuntimeError, 'exclusive coalition'):
                exact_coalition_membership(api, process_api, 10, app, 1, time.monotonic(), [])

    def test_coalition_scan_keeps_metal_tasks_and_rejects_unaccounted_tasks(self):
        import os
        import time
        @dataclass
        class Reading:
            tasks_started: int = 4
            tasks_exited: int = 2
            instructions: int = 12345
        class API:
            def read(self, cid):
                return Reading()
            def resource_coalition(self, pid):
                return 10
        app = Path('/private/fixture/Brave.app')
        paths = {1: str(app / 'Contents/MacOS/Brave'), 2: str(METAL_COMPILER)}
        class ProcessAPI:
            def path(self, pid):
                return paths[pid]
        rows = [dict(pid=pid, uid=os.getuid(), command=path) for pid, path in paths.items()]
        with patch('hacker_news_browser_instructions.processes', return_value=rows):
            attempts = []
            scan = exact_coalition_membership(API(), ProcessAPI(), 10, app, 1, time.monotonic(), attempts)
            self.assertEqual(len(scan['members']), 2)
            self.assertEqual(scan['after_snapshot']['instructions'], 12345)
            paths[2] = '/other/process'
            with self.assertRaisesRegex(RuntimeError, 'exclusive coalition'):
                exact_coalition_membership(API(), ProcessAPI(), 10, app, 1, time.monotonic(), [])
            paths[2] = str(METAL_COMPILER)
            with patch('hacker_news_browser_instructions.processes', return_value=rows[:1]):
                with self.assertRaisesRegex(RuntimeError, 'exclusive coalition'):
                    exact_coalition_membership(API(), ProcessAPI(), 10, app, 1, time.monotonic(), [])

    def check_ownership_race(self, *, exited=False, cdp=False):
        import time
        @dataclass
        class Reading:
            tasks_started: int
            tasks_exited: int = 0
        app = Path('/private/fixture/Vox.app')
        first = dict(members=[dict(pid=1), dict(pid=2)] if exited else [dict(pid=1)],
                     after_snapshot=dict(tasks_started=2 if exited else 1, tasks_exited=0))
        reading = Reading(2, 1 if exited else 0)
        second = dict(members=[dict(pid=1)] if exited else [dict(pid=1), dict(pid=2)],
                      after_snapshot=dict(tasks_started=reading.tasks_started,
                                          tasks_exited=reading.tasks_exited))
        rows = [dict(pid=1, command=str(app / 'Contents/MacOS/Vox'))]
        if not exited and not cdp:
            rows.append(dict(pid=2, command=str(app / 'Contents/MacOS/Vox') + ' --fetch-worker'))
        api = Mock()
        api.read.return_value = reading
        browser = Mock() if cdp else None
        if browser:
            browser.call.return_value = dict(processInfo=[dict(id=1), dict(id=2)])
        with patch('hacker_news_browser_instructions.exact_coalition_membership',
                   side_effect=[first, second]) as exact, \
             patch('hacker_news_browser_instructions.processes', return_value=rows):
            result = membership(api, 10, app, 1, time.monotonic() + 10, [], browser)
        self.assertEqual(exact.call_count, 2)
        self.assertIs(result, second)
        self.assertFalse(first['ownership_stable'])
        self.assertTrue(second['ownership_stable'])
        self.assertEqual(second['after_ownership_snapshot']['tasks_exited'], reading.tasks_exited)
        if browser:
            self.assertEqual(browser.call.call_count, 2)

    def test_fetch_worker_started_after_exact_scan_requires_a_new_exact_scan(self):
        self.check_ownership_race()

    def test_shared_bundle_excludes_only_preexisting_tasks_outside_measured_coalition(self):
        import time
        @dataclass
        class Reading:
            tasks_started: int = 1
            tasks_exited: int = 0
        app = Path('/private/fixture/Vox.app')
        binary = str(app / 'Contents/MacOS/Vox')
        old = dict(pid=99, command=binary + ' user-page')
        rows = [dict(pid=1, command=binary + ' unique-capture'), old]
        api = Mock()
        api.read.return_value = Reading()
        for members, succeeds in (([dict(pid=1)], True),
                                  ([dict(pid=1), dict(pid=99)], False)):
            scan = dict(members=members, after_snapshot=dict(tasks_started=1, tasks_exited=0))
            with patch('hacker_news_browser_instructions.exact_coalition_membership', return_value=scan), \
                 patch('hacker_news_browser_instructions.processes', return_value=rows):
                if succeeds:
                    result = membership(api, 10, app, 1, time.monotonic() + 10, [], existing_processes=[old])
                    self.assertEqual(result['preexisting_app_pids'], [99])
                    self.assertEqual(result['private_app_pids'], [1])
                else:
                    with self.assertRaisesRegex(RuntimeError, 'preexisting browser task'):
                        membership(api, 10, app, 1, time.monotonic() + 10, [], existing_processes=[old])

    def test_worker_exit_during_ownership_queries_requires_a_new_exact_scan(self):
        self.check_ownership_race(exited=True)

    def test_cdp_worker_started_after_exact_scan_requires_a_new_exact_scan(self):
        self.check_ownership_race(cdp=True)

    def test_stable_unaccounted_private_or_cdp_worker_still_fails_closed(self):
        import time
        @dataclass
        class Reading:
            tasks_started: int = 1
            tasks_exited: int = 0
        app = Path('/private/fixture/Vox.app')
        api = Mock()
        api.read.return_value = Reading()
        for cdp in [False, True]:
            scan = dict(members=[dict(pid=1)], after_snapshot=dict(tasks_started=1, tasks_exited=0))
            rows = [dict(pid=1, command=str(app / 'Contents/MacOS/Vox'))]
            browser = Mock() if cdp else None
            if browser:
                browser.call.return_value = dict(processInfo=[dict(id=1), dict(id=2)])
            else:
                rows.append(dict(pid=2, command=str(app / 'Contents/MacOS/Vox') + ' --fetch-worker'))
            with patch('hacker_news_browser_instructions.exact_coalition_membership',
                       return_value=scan), \
                 patch('hacker_news_browser_instructions.processes', return_value=rows):
                with self.assertRaisesRegex(RuntimeError, 'outside its .*coalition'):
                    membership(api, 10, app, 1, time.monotonic() + 10, [], browser)
            self.assertTrue(scan['ownership_stable'])

    def test_membership_churn_obeys_the_original_watchdog(self):
        import time
        @dataclass
        class Reading:
            tasks_started: int = 2
            tasks_exited: int = 0
        api = Mock()
        api.read.return_value = Reading()
        scan = dict(members=[dict(pid=1)], after_snapshot=dict(tasks_started=1, tasks_exited=0))
        with patch('hacker_news_browser_instructions.exact_coalition_membership',
                   return_value=scan) as exact, \
             patch('hacker_news_browser_instructions.processes', return_value=[]):
            with self.assertRaisesRegex(RuntimeError, 'stable exclusive coalition ownership'):
                membership(api, 10, Path('/private/fixture/Vox.app'), 1, time.monotonic() - 1, [])
        self.assertEqual(exact.call_count, 1)

    def test_code_sign_clone_requires_exact_path_private_argv_and_binary_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'measured/Brave Browser.app'
            binary = app / 'Contents/MacOS/Brave Browser'
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b'pinned browser executable')
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
                CFBundleIdentifier='com.brave.Browser', CFBundleExecutable=binary.name)))
            relative = Path('X/com.brave.Browser.code_sign_clone/code_sign_clone.123/'
                            'Brave Browser.app.bundle/Contents/MacOS/Brave Browser')
            mapped = root / relative
            mapped.parent.mkdir(parents=True)
            mapped.write_bytes(binary.read_bytes())
            command = str(binary) + ' --user-data-dir=private-profile'
            with patch('hacker_news_browser_instructions.tempfile.gettempdir', return_value=str(root / 'T')):
                identity = code_sign_clone_identity(mapped, app, command)
                self.assertEqual(identity['mapped'], str(mapped.resolve()))
                self.assertEqual(identity['original'], str(binary))
                # Identical bytes elsewhere and an unrelated process's argv are insufficient.
                for changed in [root / 'other/Brave Browser',
                                root / str(relative).replace('com.brave.Browser.', 'com.other.'),
                                root / str(relative).replace('code_sign_clone.123', 'other.123'),
                                root / str(relative).replace('app.bundle', 'other.bundle')]:
                    changed.parent.mkdir(parents=True, exist_ok=True)
                    changed.write_bytes(binary.read_bytes())
                    self.assertIsNone(code_sign_clone_identity(changed, app, command))
                self.assertIsNone(code_sign_clone_identity(mapped, app, '/other/Brave Browser --args'))
                mapped.write_bytes(b'another executable')
                self.assertIsNone(code_sign_clone_identity(mapped, app, command))

    def test_coalition_clone_exception_is_limited_to_the_authenticated_root(self):
        import os
        import time
        @dataclass
        class Reading:
            tasks_started: int = 1
            tasks_exited: int = 0
        reading = Reading()
        api = Mock()
        api.read.return_value = reading
        api.resource_coalition.return_value = 10
        process_api = Mock()
        process_api.path.return_value = '/macOS/mapped/root'
        app = Path('/private/fixture/Brave.app')
        rows = [dict(pid=1, uid=os.getuid(), command='private-root-argv')]
        with patch('hacker_news_browser_instructions.processes', return_value=rows), \
             patch('hacker_news_browser_instructions.code_sign_clone_identity', return_value={
                 'sha256': 'authenticated'}) as authenticate:
            scan = exact_coalition_membership(api, process_api, 10, app, 1, time.monotonic(), [])
            self.assertEqual(scan['members'][0]['code_sign_clone_identity']['sha256'], 'authenticated')
            authenticate.assert_called_once_with('/macOS/mapped/root', app, 'private-root-argv')
            authenticate.reset_mock()
            rows.append(dict(pid=2, uid=os.getuid(), command='unrelated-helper'))
            reading.tasks_started = 2
            with self.assertRaisesRegex(RuntimeError, 'exclusive coalition'):
                exact_coalition_membership(api, process_api, 10, app, 1, time.monotonic(), [])
            # A matching clone is authenticated only for the measured root PID.
            authenticate.assert_called_once_with('/macOS/mapped/root', app, 'private-root-argv')

    def test_replay_serves_only_the_frozen_document_and_its_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            document = root / 'discussion.html'
            document.write_bytes(b'<title>Frozen discussion</title>')
            assets = root / ASSETS
            assets.mkdir()
            (assets / 'news.css').write_bytes(b'body { color: black }')
            (root / 'unrelated.html').write_bytes(b'Not part of this fixture')
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            with fixture_server(document, root) as url:
                with opener.open(url) as response:
                    self.assertEqual(response.read(), document.read_bytes())
                    self.assertEqual(response.headers['Cache-Control'], 'no-store')
                origin = url.rsplit('/', 1)[0]
                with opener.open(origin + '/' + ASSETS + '/news.css?v=1') as response:
                    self.assertEqual(response.read(), (assets / 'news.css').read_bytes())
                for route in ['/unrelated.html', '/../unrelated.html']:
                    with self.assertRaises(HTTPError) as error:
                        opener.open(origin + route)
                    self.assertEqual(error.exception.code, 404)

    def test_checks_every_comment_after_capture_against_independent_source_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            document = Path(directory) / 'discussion.html'
            document.write_text('<table><tr class="athing comtr" id="a"></tr>'
                                '<tr class="athing comtr noshow" id="b"></tr></table>')
            ids = document_comments(document)
            self.assertEqual(ids, ['a', 'b'])
            audit = dict(url='http://fixture/', ready='complete', viewport_width=WIDTH,
                         viewport_height=HEIGHT, selections=[dict(name='comments', count=2,
                         elements=[dict(attributes=dict(id=value)) for value in ids])])
            check_content(audit, 'http://fixture/', ids)
            with self.assertRaisesRegex(RuntimeError, 'identity'):
                check_content(audit, 'http://wrong/', ids)
            for changed in [['a'], ['b', 'a'], ['a', 'wrong']]:
                with self.assertRaisesRegex(RuntimeError, 'comment rows'):
                    check_content(audit, 'http://fixture/', changed)
            document.write_text('<tr class="comtr" id="a"><tr class="comtr" id="a">')
            with self.assertRaisesRegex(RuntimeError, 'unique'):
                document_comments(document)


if __name__ == '__main__':
    unittest.main()
