from dataclasses import dataclass
import errno
import json
import unittest
from unittest.mock import Mock

from hacker_news_browser_instructions import rejected_process_identities


@dataclass
class Reading:
    start: int
    exited: bool = False


class RejectedBrowserHelperTests(unittest.TestCase):
    def setUp(self):
        self.process, self.coalition = Mock(), Mock()
        self.process.read.side_effect = [Reading(123), Reading(123)]
        self.process.path.return_value = '/fixture/Brave.app/Contents/Helpers/cleanup'
        self.coalition.resource_coalition.side_effect = [20, 20]
        self.rows = [dict(pid=7, parent=1, command='helper --cleanup')]

    def test_rejected_helper_keeps_stable_identity_without_an_exemption(self):
        result = rejected_process_identities(self.process, self.coalition, self.rows)
        self.assertEqual(result[0]['start_ticks'], 123)
        self.assertEqual(result[0]['resource_coalition'], 20)
        self.assertEqual(result[0]['executable'], self.process.path.return_value)
        self.assertTrue(result[0]['identity_stable'])
        self.assertNotIn('accepted', result[0])
        self.assertEqual(self.rows, [dict(pid=7, parent=1, command='helper --cleanup')])
        json.dumps(result)

    def test_recycled_moved_or_exited_helper_is_not_a_stable_identity(self):
        for changed in ['start', 'coalition', 'exited']:
            with self.subTest(changed=changed):
                self.setUp()
                self.process.read.side_effect = [Reading(123), Reading(124 if changed == 'start' else 123,
                                                                        changed == 'exited')]
                self.coalition.resource_coalition.side_effect = [20, 21 if changed == 'coalition' else 20]
                result = rejected_process_identities(self.process, self.coalition, self.rows)
                self.assertFalse(result[0]['identity_stable'])

    def test_vanished_or_inaccessible_helper_retains_the_original_failure_evidence(self):
        for code in [errno.ESRCH, errno.EACCES]:
            with self.subTest(errno=code):
                self.setUp()
                self.process.read.side_effect = OSError(code, 'identity unavailable')
                result = rejected_process_identities(self.process, self.coalition, self.rows)
                self.assertEqual(result[0]['pid'], 7)
                self.assertEqual(result[0]['command'], 'helper --cleanup')
                self.assertFalse(result[0]['identity_stable'])
                self.assertIn('identity unavailable', result[0]['identity_error'])


if __name__ == '__main__':
    unittest.main()
