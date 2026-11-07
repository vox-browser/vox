import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import ProxyHandler, Request, build_opener

from wpt_compare import (WARMUP, Limits, Runner, RunAborted, Server, Session, discover_tests,
                         group_rss, make_handler, signal_process_group, substitute, summarize,
                         upstream_testharness)

HARNESS = ('var settings = { output: !(globalThis.internals && globalThis.internals.headless),\n'
           'harness_timeout:{ "normal":150000, "long":300000 } };\n'
           'if (globalThis.internals) globalThis.internals.setTestTimeout(1);\n')


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def record(browser, test, ms, statuses=('PASS',), harness='OK'):
    return dict(browser=browser, test=test, outcome='COMPLETE', harness=harness, document_ms=ms,
                subtests=[dict(name=f's{index}', status=status) for index, status in enumerate(statuses)])


class DiscoveryTests(unittest.TestCase):
    def test_expectations_name_documents_variants_and_long_timeouts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write(root / 'expected/wpt-import/dom/a.txt', '')
            write(root / 'expected/wpt-import/dom/b@x=1.txt', '')
            write(root / 'expected/wpt-import/dom/missing.txt', '')
            write(root / 'expected/wpt-import/css/c.any.txt', '')
            write(root / 'input/wpt-import/dom/a.html', '<meta name="timeout" content="long">')
            write(root / 'input/wpt-import/dom/b.xhtml', '')
            write(root / 'input/wpt-import/css/c.any.html', '')
            tests = discover_tests(root)
            self.assertEqual([test['id'] for test in tests], ['css/c.any', 'dom/a', 'dom/b?x=1'])
            self.assertEqual(tests[1]['harness_timeout'], 60)
            self.assertEqual(tests[2]['url'], '/dom/b.xhtml?x=1')
            self.assertEqual(tests[2]['harness_timeout'], 10)
            self.assertEqual([test['id'] for test in discover_tests(root, ['dom'])], ['dom/a', 'dom/b?x=1'])

    def test_harness_is_served_with_upstream_timeouts_and_no_internals_shortcuts(self):
        source = upstream_testharness(HARNESS)
        self.assertIn('"normal":10000', source)
        self.assertIn('"long":60000', source)
        self.assertNotIn('globalThis.internals', source)
        with self.assertRaises(ValueError):
            upstream_testharness(HARNESS.replace('150000', '10000'))

    def test_substitution_covers_single_origin_templates(self):
        body = b'{{host}}:{{ports[http][0]}} {{domains[www]}} {{location[server]}} {{GET[a]}}'
        self.assertEqual(substitute(body, '127.0.0.1', 8000),
                         b'127.0.0.1:8000 localhost http://127.0.0.1:8000 {{GET[a]}}')


class SessionTests(unittest.TestCase):
    def test_each_phase_has_its_own_deadline(self):
        limits = Limits(startup=30, navigation=10, harness_start=5, grace=7)
        session = Session('vox', [dict(id='t', url='/t.html', harness_timeout=60)], 0, [],
                          now=100, warmup=False)
        self.assertEqual(session.deadline(limits), (130, 'NO_DOCUMENT'))
        session.document_requested_at = 131
        self.assertEqual(session.deadline(limits), (136, 'NO_HARNESS'))
        session.harness_seen_at = 132
        self.assertEqual(session.deadline(limits), (199, 'HARD_TIMEOUT'))
        session.first_of_launch = False
        session.document_requested_at = session.harness_seen_at = None
        self.assertEqual(session.deadline(limits), (110, 'NO_DOCUMENT'))

    def test_warmup_is_not_recorded_and_results_advance_through_the_chunk(self):
        tests = [dict(id='a', url='/a.html', harness_timeout=10),
                 dict(id='b', url='/b%20c.html?x=1', harness_timeout=10)]
        records = []
        runner = Runner()
        session = Session('brave', tests, 0, records, 'brave-000-000')
        runner.begin(session)
        self.assertEqual(session.current, WARMUP)
        result = dict(harness=dict(status=0), tests=[dict(name='n', status=0)])
        self.assertEqual(runner.accept(result), '/a.html')
        runner.note_request('/a.html')
        runner.note_request('/resources/testharnessreport.js')
        self.assertIsNotNone(session.harness_seen_at)
        self.assertEqual(runner.accept(dict(result, url='/a.html')), '/b%20c.html?x=1')
        runner.note_request('/b c.html?x=1')
        self.assertIsNotNone(session.document_requested_at)
        # A cached harness is not requested again; its alive ping still counts.
        self.assertIsNone(session.harness_seen_at)
        runner.note_harness()
        self.assertIsNotNone(session.harness_seen_at)
        self.assertEqual(runner.abandon(session, 'HARD_TIMEOUT'), 2)
        self.assertIsNone(runner.accept(result))
        self.assertEqual(runner.unexpected_posts, 1)
        self.assertEqual([(item['test'], item['outcome']) for item in records],
                         [('a', 'COMPLETE'), ('b', 'HARD_TIMEOUT')])
        self.assertEqual(records[0]['subtests'], [dict(name='n', status='PASS', message=None)])
        self.assertTrue(records[0]['url_matches'])
        self.assertIsNotNone(records[0]['document_ms'])

    def test_a_launch_that_cannot_run_the_warmup_stops_the_run(self):
        runner = Runner()
        session = Session('vox', [dict(id='a', url='/a.html', harness_timeout=10)], 0, [])
        runner.begin(session)
        with self.assertRaises(RunAborted):
            runner.abandon(session, 'NO_HARNESS')


class SummaryTests(unittest.TestCase):
    def test_timing_uses_only_clean_completions_in_both_browsers(self):
        tests = [dict(id=name) for name in ('a', 'b', 'c', 'd')]
        records = [
            record('vox', 'a', 40), record('brave', 'a', 10),
            record('vox', 'b', 20, ('FAIL',)), record('brave', 'b', 20),
            record('vox', 'c', 10_000, harness='TIMEOUT'), record('brave', 'c', 10),
            dict(browser='vox', test='d', outcome='NO_HARNESS', harness=None, subtests=[], document_ms=None),
            record('brave', 'd', 10)]
        summary = summarize(tests, records, [dict(browser='vox', seconds=3, launches=2),
                                             dict(browser='brave', seconds=1, launches=1)])
        self.assertEqual(summary['both_clean']['tests'], 2)
        self.assertEqual(summary['both_clean']['total_ratio'], 2.0)
        self.assertEqual(summary['both_clean']['ratio_geomean'], 2.0)
        self.assertEqual(summary['identical_results']['tests'], 1)
        self.assertEqual(summary['identical_results']['total_ratio'], 4.0)
        self.assertEqual(summary['browsers']['vox']['outcomes'], dict(COMPLETE=3, NO_HARNESS=1))
        self.assertEqual(summary['browsers']['brave']['subtest_pass_rate'], 1.0)
        self.assertEqual(summary['launches'], dict(vox=2, brave=1))


class MemoryTests(unittest.TestCase):
    def test_group_rss_sums_only_the_browser_process_group(self):
        output = '  412  1000\n  412     24\n 4120  9999\n   41  7777\n'
        self.assertEqual(group_rss(output, 412), 1024 * 1024)
        self.assertEqual(group_rss(output, 9), 0)

    def test_signalling_an_exited_process_group_is_not_an_error(self):
        sent = []

        def killpg(pid, number):
            sent.append((pid, number))
            raise PermissionError(1, 'Operation not permitted')

        signal_process_group(412, 15, killpg=killpg)
        signal_process_group(412, 9, killpg=lambda *_: (_ for _ in ()).throw(ProcessLookupError()))
        self.assertEqual(sent, [(412, 15)])


class ServerTests(unittest.TestCase):
    def test_server_serves_patched_harness_headers_and_runner_results(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'www'
            write(Path(directory) / 'outside.txt', 'secret')
            write(root / 'resources/testharness.js', HARNESS)
            write(root / 'dom/a.html', '<p>a')
            write(root / 'dom/a.html.headers', 'Content-Type: text/html; charset=windows-1252\nX-Test: 1')
            write(root / 'dom/b.sub.js', '{{host}}')
            runner = Runner()
            port = [0]
            server = Server(('127.0.0.1', 0), make_handler(runner, root, '127.0.0.1', port))
            port[0] = server.server_address[1]
            threading.Thread(target=server.serve_forever, daemon=True).start()
            base = f'http://127.0.0.1:{port[0]}'
            # Ambient proxy settings must not intercept loopback requests.
            urlopen = build_opener(ProxyHandler({})).open
            try:
                with urlopen(base + '/dom/a.html') as response:
                    self.assertEqual(response.headers['Content-Type'], 'text/html; charset=windows-1252')
                    self.assertEqual(response.headers['X-Test'], '1')
                    self.assertEqual(response.headers['Cache-Control'], 'no-store')
                with urlopen(base + '/resources/testharness.js') as response:
                    self.assertIn(b'"normal":10000', response.read())
                with urlopen(base + '/resources/testharnessreport.js') as response:
                    self.assertIn(b'add_completion_callback', response.read())
                with urlopen(base + '/dom/b.sub.js') as response:
                    self.assertEqual(response.read(), b'127.0.0.1')
                with self.assertRaises(HTTPError) as missing:
                    urlopen(base + '/..%2Foutside.txt')
                self.assertEqual(missing.exception.code, 404)
                session = Session('brave', [dict(id='a', url='/dom/a.html', harness_timeout=10)], 0, [])
                runner.begin(session)
                body = json.dumps(dict(harness=dict(status=0), tests=[])).encode()
                post = Request(base + '/__vox_wpt__/result', body, {'Content-Type': 'application/json'})
                with urlopen(post) as response:
                    self.assertEqual(json.loads(response.read()), dict(next='/dom/a.html'))
            finally:
                server.shutdown()
                server.server_close()


if __name__ == '__main__':
    unittest.main()
