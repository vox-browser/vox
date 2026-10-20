import tempfile
from pathlib import Path
import unittest
from unittest.mock import Mock, call, patch

from capture_brave_reference import imported_cookies, launch_command, resize_native_viewport, window_position


class BraveReferenceTests(unittest.TestCase):
    def test_session_cookies_keep_http_only_domain_and_secure_attributes(self):
        with tempfile.TemporaryDirectory() as directory:
            jar = Path(directory) / 'cookies.txt'
            jar.write_text('# Netscape HTTP Cookie File\n'
                           '#HttpOnly_.reddit.com\tTRUE\t/\tTRUE\t0\treddit_session\tfixture\n'
                           'old.reddit.com\tFALSE\t/r\tFALSE\t0\tview\tcompact\n'
                           '.reddit.com\tTRUE\t/\tFALSE\t1\texpired\tfixture\n')
            self.assertEqual(imported_cookies(jar), [
                dict(name='reddit_session', value='fixture', domain='.reddit.com',
                     path='/', secure=True, httpOnly=True),
                dict(name='view', value='compact', domain='old.reddit.com',
                     path='/r', secure=False, httpOnly=False)])

    def test_socks_proxy_is_process_local_and_uses_remote_dns(self):
        command = launch_command('brave', '/tmp/isolated', 'socks5h://127.0.0.1:1337')
        self.assertIn('--proxy-server=socks5://127.0.0.1:1337', command)
        self.assertIn('--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost, EXCLUDE 127.0.0.1', command)
        self.assertIn('--user-data-dir=/tmp/isolated', command)
        self.assertEqual(command[-1], 'about:blank')
        self.assertFalse(any('proxy-server' in item for item in launch_command('brave', '/tmp/isolated')))

    def test_malformed_cookie_rows_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            jar = Path(directory) / 'cookies.txt'
            for row in ['bad\trow', '.reddit.com\tMAYBE\t/\tTRUE\t0\ta\tb',
                        '.reddit.com\tTRUE\t/\tTRUE\t-1\ta\tb',
                        '.reddit.com\tTRUE\trelative\tTRUE\t0\ta\tb']:
                jar.write_text(row + '\n')
                with self.assertRaises(ValueError):
                    imported_cookies(jar)

    def test_windowed_launch_waits_for_a_background_target_at_the_requested_position(self):
        command = launch_command('brave', '/tmp/isolated', windowed=True)
        self.assertNotIn('--headless=new', command)
        self.assertNotIn('about:blank', command)
        self.assertIn('--no-startup-window', command)
        self.assertEqual(window_position('-1100,32'), (-1100, 32))

    def test_native_viewport_resize_accounts_for_browser_chrome(self):
        browser = Mock()
        browser.call.side_effect = [dict(windowId=7),
                                    dict(bounds=dict(width=1104, height=824)), {}]
        cdp = Mock()
        cdp.call.side_effect = [dict(result=dict(value=viewport)) for viewport in
                               [dict(width=1088, height=728, scale=2),
                                dict(width=1024, height=684, scale=2)]]
        with patch('capture_brave_reference.time.sleep'):
            actual = resize_native_viewport(browser, cdp, 'page', 1024, 684, 2)
        self.assertEqual(actual, dict(width=1024, height=684, scale=2))
        self.assertIn(call('Browser.setWindowBounds', {
            'windowId': 7, 'bounds': dict(width=1040, height=780)}), browser.call.call_args_list)

    def test_native_capture_rejects_a_different_display_scale(self):
        browser = Mock()
        browser.call.return_value = dict(windowId=7)
        cdp = Mock()
        cdp.call.return_value = dict(result=dict(value=dict(width=1024, height=684, scale=1)))
        with self.assertRaisesRegex(RuntimeError, 'Native display scale'):
            resize_native_viewport(browser, cdp, 'page', 1024, 684, 2)

    def test_native_capture_rejects_a_window_manager_size_limit(self):
        browser = Mock()
        browser.call.side_effect = lambda method, params: (
            dict(windowId=7) if method == 'Browser.getWindowForTarget' else
            dict(bounds=dict(width=1104, height=824)))
        cdp = Mock()
        cdp.call.return_value = dict(result=dict(value=dict(width=1088, height=728, scale=2)))
        with patch('capture_brave_reference.time.sleep'), self.assertRaisesRegex(RuntimeError, 'could not resize'):
            resize_native_viewport(browser, cdp, 'page', 2048, 1368, 2)


if __name__ == '__main__':
    unittest.main()
