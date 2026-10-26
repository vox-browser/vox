from pathlib import Path
from dataclasses import dataclass
from unittest.mock import Mock, patch
import plistlib
import tempfile
import unittest
from urllib.error import HTTPError
import urllib.request

from hacker_news_browser_instructions import (
    ASSETS, WIDTH, HEIGHT, METAL_COMPILER, accepted_coalition_executable,
    check_content, code_sign_clone_identity, document_comments, evaluate_pairs,
    exact_coalition_membership, fixture_server,
)


def observation(lower, upper=None, **changes):
    return dict(exit=0, pixels_exact=True, content_exact=True,
                instruction_interval=dict(lower=lower, upper=lower if upper is None else upper),
                **changes)


class HackerNewsInstructionGateTests(unittest.TestCase):
    def pairs(self, vox=900, brave=1000):
        return [dict(vox=observation(vox), brave=observation(brave)) for _ in range(2)]

    def test_ten_percent_reduction_is_inclusive(self):
        self.assertTrue(evaluate_pairs(self.pairs())['passed'])
        self.assertFalse(evaluate_pairs(self.pairs(vox=901))['passed'])
        self.assertTrue(evaluate_pairs(self.pairs(vox=100))['passed'])

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

    def test_only_private_browser_and_exact_metal_service_paths_are_accepted(self):
        app = Path('/private/fixture/Brave.app')
        self.assertTrue(accepted_coalition_executable(app / 'Contents/MacOS/Brave', app))
        self.assertTrue(accepted_coalition_executable(METAL_COMPILER, app))
        for path in [Path('/Applications/Brave.app/Contents/MacOS/Brave'),
                     app / 'Contents/../../other', Path(str(METAL_COMPILER) + '-other')]:
            self.assertFalse(accepted_coalition_executable(path, app))

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
