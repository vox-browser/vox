import io
import json
import unittest
from unittest.mock import Mock, patch

from capture_brave_reference import wait_for_page_debugger


class PageTargetTests(unittest.TestCase):
    def test_waits_for_initial_page_after_debugger_becomes_ready(self):
        opener = Mock()
        opener.open.side_effect = [io.BytesIO(json.dumps(targets).encode()) for targets in
            [[], [dict(type='service_worker')],
             [dict(type='page', webSocketDebuggerUrl='ws://page')]]]
        with patch('capture_brave_reference.time.monotonic', side_effect=[1, 2, 3]), \
                patch('capture_brave_reference.time.sleep') as sleep:
            self.assertEqual(wait_for_page_debugger(opener, 1234, 10), 'ws://page')
        self.assertEqual(opener.open.call_count, 3)
        self.assertEqual(sleep.call_count, 2)
        self.assertEqual(opener.open.call_args.kwargs['timeout'], 7)

    def test_missing_page_stops_at_original_deadline(self):
        opener = Mock()
        opener.open.return_value = io.BytesIO(b'[]')
        with patch('capture_brave_reference.time.monotonic', side_effect=[9.98, 10]), \
                patch('capture_brave_reference.time.sleep'):
            with self.assertRaisesRegex(RuntimeError, 'page target'):
                wait_for_page_debugger(opener, 1234, 10)
        self.assertLess(opener.open.call_args.kwargs['timeout'], .03)

    def test_invalid_debugger_response_is_not_treated_as_a_missing_page(self):
        opener = Mock()
        opener.open.return_value = io.BytesIO(b'invalid JSON')
        with patch('capture_brave_reference.time.monotonic', return_value=1):
            with self.assertRaises(json.JSONDecodeError):
                wait_for_page_debugger(opener, 1234, 10)


if __name__ == '__main__':
    unittest.main()
