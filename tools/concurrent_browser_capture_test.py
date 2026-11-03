"""Ownership checks for independently launched captures of shared app bundles."""
import errno
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from hacker_news_browser_instructions import private_capture_marker, verified_concurrent_capture_tasks


class ConcurrentCaptureOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.app = Path('/private/fixture/Vox.app')
        self.binary = self.app / 'Contents/MacOS/Vox'
        self.rows = [
            dict(pid=1, parent=100, uid=501, command=str(self.binary)+' --screenshot /private/ours.png https://www.bbc.com/'),
            dict(pid=10, parent=1_000, uid=501, command=str(self.binary)+' --screenshot /private/other.png https://news.ycombinator.com/'),
            dict(pid=11, parent=10, uid=501, command=str(self.app / 'Contents/MacOS/VoxAdblockWorker')+' --vox-adblock-worker-v1'),
        ]
        self.starts = {1:101, 10:110, 11:111}
        self.cids = {1:10, 10:20, 11:20}
        self.paths = {1:str(self.binary),10:str(self.binary),11:str(self.app / 'Contents/MacOS/VoxAdblockWorker')}
        self.process = Mock()
        self.process.read.side_effect = lambda pid: SimpleNamespace(start=self.starts[pid], exited=False)
        self.process.path.side_effect = lambda pid:self.paths[pid]
        self.coalition = Mock()
        self.coalition.resource_coalition.side_effect = lambda pid:self.cids[pid]

    def verify(self, observed=None):
        with patch('hacker_news_browser_instructions.processes',return_value=self.rows if observed is None else observed):
            return verified_concurrent_capture_tasks(self.process,self.coalition,10,self.app,1,self.rows)

    def test_distinct_capture_and_its_helpers_are_pinned(self):
        roots,tasks=self.verify()
        self.assertEqual([r['pid']for r in roots],[10])
        self.assertEqual({t['pid']for t in tasks},{10,11})
        self.assertEqual(roots[0]['private_marker'],['--screenshot','/private/other.png'])
        self.assertEqual(tasks[1]['resource_coalition'],20)
        self.assertEqual(tasks[1]['start_ticks'],111)
        self.assertEqual(tasks[1]['independent_root_pids'],[10])

    def test_reparented_helper_requires_the_anchored_coalition(self):
        self.rows[2]['parent']=1_000
        self.assertEqual({t['pid']for t in self.verify()[1]},{10,11})
        self.cids[11]=30
        self.assertEqual({t['pid']for t in self.verify()[1]},{10})

    def test_descendant_of_measured_root_is_never_exempted(self):
        self.rows[1]['parent']=1
        self.assertEqual(self.verify(),([],[]))

    def test_measured_coalition_and_same_capture_are_never_exempted(self):
        self.cids[10]=10
        self.assertEqual(self.verify(),([],[]))
        self.cids[10]=20
        self.rows[1]['command']=self.rows[0]['command']
        self.assertEqual(self.verify(),([],[]))

    def test_other_user_windows_without_private_identity_are_not_guessed(self):
        self.rows[1]['command']=str(self.binary)+' vox://newtab'
        self.assertEqual(self.verify(),([],[]))

    def test_executable_must_authenticate_the_foreign_root(self):
        self.paths[10]='/private/unrelated/program'
        self.assertEqual(self.verify(),([],[]))

    def test_exited_and_recycled_roots_are_not_exempted(self):
        self.process.read.return_value=None
        self.process.read.side_effect=lambda pid:SimpleNamespace(start=self.starts[pid],exited=pid==10)
        self.assertEqual(self.verify(),([],[]))
        reads={}
        def read(pid):
            reads[pid]=reads.get(pid,0)+1
            return SimpleNamespace(start=self.starts[pid]+(1 if pid==10 and reads[pid]>1 else 0),exited=False)
        self.process.read.side_effect=read
        self.assertEqual(self.verify(),([],[]))

    def test_changed_live_command_cannot_use_old_snapshot(self):
        observed=[dict(r)for r in self.rows]
        observed[1]['command']=str(self.binary)+' --screenshot /private/reused.png https://www.bbc.com/'
        self.assertEqual(self.verify(observed),([],[]))

    def test_changed_helper_command_and_older_tasks_are_not_exempted(self):
        observed=[dict(r)for r in self.rows];observed[2]['command']+=' changed'
        self.assertEqual({t['pid']for t in self.verify(observed)[1]},{10})
        self.starts[11]=109
        self.assertEqual({t['pid']for t in self.verify()[1]},{10})

    def test_missing_tasks_are_conservative_but_counter_denials_propagate(self):
        self.process.path.side_effect=lambda pid:(_ for _ in ()).throw(OSError(errno.ESRCH,'gone'))
        self.assertEqual(self.verify(),([],[]))
        self.process.path.side_effect=PermissionError(errno.EPERM,'denied')
        with self.assertRaises(PermissionError):self.verify()

    def test_changed_root_coalition_invalidates_its_helper_exemptions(self):
        reads={}
        def coalition(pid):
            reads[pid]=reads.get(pid,0)+1
            return 30 if pid==10 and reads[pid]>1 else self.cids[pid]
        self.coalition.resource_coalition.side_effect=coalition
        self.assertEqual(self.verify(),([],[]))

    def test_private_marker_parsing_is_strict(self):
        brave=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser')
        self.assertEqual(private_capture_marker(str(brave)+' --user-data-dir=/private/profile --no-startup-window',brave),('--user-data-dir','/private/profile'))
        for args in ['--screenshot relative.png','--screenshot /private/a --screenshot /private/b','--screenshot "unterminated','https://www.bbc.com/']:
            self.assertIsNone(private_capture_marker(str(self.binary)+' '+args,self.binary))
        self.assertIsNone(private_capture_marker(str(self.binary)+' --screenshot /private/a',brave))


if __name__=='__main__':unittest.main()
