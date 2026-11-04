from dataclasses import dataclass
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from hacker_news_browser_instructions import verified_preexisting_descendants


@dataclass
class Reading:
    start: int
    exited: bool = False


class PreexistingBrowserHelpersTests(unittest.TestCase):
    def setUp(self):
        self.app = Path('/fixture/Brave Browser.app')
        self.binary = str(self.app / 'Contents/MacOS/Brave Browser')
        self.helper = str(self.app / 'Contents/Helpers/renderer')
        self.rows = [dict(pid=1, parent=0, uid=501, command=self.binary+' --user-data-dir=/ours'),
                     dict(pid=99, parent=1, uid=501, command=self.binary+' user-window'),
                     dict(pid=100, parent=99, uid=501, command=self.helper+' --type=renderer')]
        # The unrelated root need not be a direct OS child of init; ancestry
        # above an authenticated preexisting root is irrelevant to its helpers.
        self.rows[1]['parent'] = 0
        self.previous = [dict(self.rows[1], start_ticks=123, resource_coalition=20)]
        self.starts = {1:200, 99:123, 100:300}
        self.coalitions = {1:10, 99:20, 100:20}
        self.process, self.coalition = Mock(), Mock()
        self.process.read.side_effect = lambda pid: Reading(self.starts[pid])
        self.process.path.side_effect = lambda pid: self.helper if pid==100 else self.binary
        self.coalition.resource_coalition.side_effect = lambda pid:self.coalitions[pid]

    def run_check(self, observed=None, excluded=None):
        with patch('hacker_news_browser_instructions.processes',
                   return_value=self.rows if observed is None else observed):
            return verified_preexisting_descendants(self.process,self.coalition,10,
                self.app,1,self.rows,self.previous,{99}if excluded is None else excluded)

    def test_new_renderer_of_pinned_user_window_is_authenticated(self):
        result = self.run_check()
        self.assertEqual([row['pid']for row in result],[100])
        self.assertEqual(result[0]['start_ticks'],300)
        self.assertEqual(result[0]['resource_coalition'],20)
        self.assertEqual(result[0]['ancestry'][0]['start_ticks'],123)
        self.assertEqual(result[0]['preexisting_root_pid'],99)

    def test_pinned_interactive_root_without_arguments_is_authenticated(self):
        self.rows[1]['command'] = self.binary
        self.previous[0]['command'] = self.binary
        self.assertEqual([row['pid'] for row in self.run_check()], [100])

    def test_argument_free_root_keeps_all_identity_and_ancestry_guards(self):
        for change in ['root_start', 'root_coalition', 'helper_coalition', 'parent', 'prefix']:
            with self.subTest(change=change):
                self.setUp()
                self.rows[1]['command'] = self.binary
                self.previous[0]['command'] = self.binary
                if change == 'root_start':
                    self.starts[99] += 1
                elif change == 'root_coalition':
                    self.coalitions[99] = 30
                elif change == 'helper_coalition':
                    self.coalitions[100] = 10
                elif change == 'parent':
                    self.rows[2]['parent'] = 1
                else:
                    self.rows[1]['command'] = self.binary + '-other'
                self.assertEqual(self.run_check(), [])

    def test_helper_in_measured_coalition_is_never_exempt(self):
        self.coalitions[100]=10
        self.assertEqual(self.run_check(),[])

    def test_escaped_child_of_measured_root_is_not_exempt(self):
        self.rows[2]['parent']=1
        self.assertEqual(self.run_check(),[])

    def test_unrelated_or_reparented_helper_requires_observed_ancestry(self):
        for parent in [0,100,12345]:
            with self.subTest(parent=parent):
                self.rows[2]['parent']=parent
                self.assertEqual(self.run_check(),[])

    def test_recycled_root_pid_or_changed_root_coalition_is_not_exempt(self):
        self.starts[99]=124
        self.assertEqual(self.run_check(),[])
        self.starts[99]=123
        self.coalitions[99]=30
        self.assertEqual(self.run_check(),[])

    def test_changed_or_exited_child_during_identity_reads_is_not_exempt(self):
        for changed in [Reading(301),Reading(300,True)]:
            counts={}
            def read(pid):
                counts[pid]=counts.get(pid,0)+1
                return changed if pid==100 and counts[pid]==2 else Reading(self.starts[pid])
            self.process.read.side_effect=read
            self.assertEqual(self.run_check(),[])

    def test_root_change_after_child_verification_is_not_exempt(self):
        counts={}
        def read(pid):
            counts[pid]=counts.get(pid,0)+1
            return Reading(124 if pid==99 and counts[pid]>=3 else self.starts[pid])
        self.process.read.side_effect=read
        self.assertEqual(self.run_check(),[])

    def test_final_argv_or_ancestry_change_is_not_exempt(self):
        for key,value in [('command',self.helper+' changed'),('parent',1)]:
            observed=[dict(row)for row in self.rows]
            observed[2][key]=value
            self.assertEqual(self.run_check(observed),[])

    def test_foreign_executable_or_older_child_is_not_exempt(self):
        self.process.path.side_effect=lambda pid:'/fixture/Other.app/renderer'if pid==100 else self.binary
        self.assertEqual(self.run_check(),[])
        self.process.path.side_effect=lambda pid:self.helper if pid==100 else self.binary
        self.starts[100]=122
        self.assertEqual(self.run_check(),[])

    def test_unpinned_or_missing_root_is_not_exempt(self):
        self.assertEqual(self.run_check(excluded=set()),[])
        self.previous=[]
        self.assertEqual(self.run_check(),[])


if __name__=='__main__':
    unittest.main()
