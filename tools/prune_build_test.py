import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import time
import unittest
from unittest.mock import patch

import prune_build

OLD = time.time() - 48 * 3600


def write(path, data=b'x', mtime=OLD):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    os.utime(path, (mtime, mtime))
    return path


def age(path, mtime=OLD):
    for current, dirs, files in os.walk(path):
        for name in dirs + files:
            os.utime(os.path.join(current, name), (mtime, mtime), follow_symlinks=False)
    os.utime(path, (mtime, mtime))


class PruneBuildTests(unittest.TestCase):
    def prune(self, root, held=frozenset(), **options):
        with patch('prune_build.held_paths', return_value=set(held)):
            return prune_build.prune(root, **options)

    def test_idle_job_output_goes_and_shared_build_state_stays(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            build = root / 'Build'
            write(build / 'bbc-cohort-1/result.json')
            write(build / 'session.guard.json')
            write(build / 'session.lock')
            write(build / 'fresh-job/log.txt', mtime=time.time())
            for name in ('deps/skia/lib.a', 'libregex/libregex.a', 'pixel-tools/pixel_diff',
                         'production-build/latest.json', 'v/Vox.app/Contents/MacOS/Vox',
                         'v/libVoxAVIF.dylib'):
                write(build / name)
            write(build / 'v/compiler-output.abc123/Vox.o')
            write(build / 'v/Vox-profile.c')
            age(build / 'bbc-cohort-1')
            age(build / 'v/compiler-output.abc123')
            report = self.prune(root)
            removed = {Path(path).relative_to(build).as_posix() for _, path, _ in report}
            self.assertEqual(removed, {'bbc-cohort-1', 'session.guard.json', 'session.lock',
                                       'v/compiler-output.abc123', 'v/Vox-profile.c'})
            self.assertTrue((build / 'fresh-job/log.txt').exists())
            self.assertTrue((build / 'v/Vox.app/Contents/MacOS/Vox').exists())
            self.assertTrue((build / 'pixel-tools/pixel_diff').exists())

    def test_recent_change_deep_inside_an_entry_keeps_it(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            job = root / 'Build/long-job'
            write(job / 'old.log')
            write(job / 'nested/deeper/progress.json', mtime=time.time())
            os.utime(job, (OLD, OLD))
            self.assertEqual(self.prune(root), [])
            self.assertTrue(job.exists())

    def test_held_files_and_working_directories_keep_their_entry(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            build = root / 'Build'
            held = write(build / 'running/guard.lock')
            write(build / 'waiting-cwd/notes.txt')
            age(build / 'running')
            self.prune(root, held={build / 'running', build / 'waiting-cwd'})
            self.assertTrue(held.exists())
            self.assertTrue((build / 'waiting-cwd/notes.txt').exists())

    def test_a_file_this_process_holds_open_is_found_by_lsof(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            lock = write(root / 'Build/guarded/job.lock')
            age(root / 'Build/guarded')
            with lock.open('rb'):
                self.assertIn((root / 'Build/guarded').resolve(), prune_build.held_paths(root / 'Build'))
                self.assertEqual(prune_build.prune(root), [])
            self.assertTrue(lock.exists())

    def test_unknown_process_state_refuses_to_prune(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            write(root / 'Build/old-job/result.json')
            with patch('prune_build.held_paths', return_value=None):
                with self.assertRaises(RuntimeError):
                    prune_build.prune(root)
            self.assertTrue((root / 'Build/old-job/result.json').exists())

    def test_links_to_the_shared_bundle_are_removed_without_touching_it(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            build = root / 'Build'
            app = write(build / 'v/Vox.app/Contents/MacOS/Vox')
            (build / 'trial/vox').mkdir(parents=True)
            (build / 'trial/vox/Vox.app').symlink_to(build / 'v/Vox.app', target_is_directory=True)
            age(build / 'trial')
            self.prune(root)
            self.assertFalse((build / 'trial').exists())
            self.assertTrue(app.exists())

    def test_read_only_scratch_directories_are_removed(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            sealed = write(root / 'Build/copied-app/Vox.app/Contents/Info.plist').parent
            age(root / 'Build/copied-app')
            sealed.chmod(0o555)
            self.prune(root)
            self.assertFalse((root / 'Build/copied-app').exists())

    @unittest.skipUnless(sys.platform == 'darwin', 'user-immutable flags are a macOS detail')
    def test_user_immutable_sealed_copies_are_removed(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            contents = write(root / 'Build/sealed-browser/Brave Browser.app/Contents/Info.plist').parent
            age(root / 'Build/sealed-browser')
            subprocess.run(['chflags', 'uchg', str(contents)], check=True)
            try:
                report = self.prune(root)
            finally:
                subprocess.run(['chflags', '-R', 'nouchg', directory], capture_output=True)
            self.assertFalse((root / 'Build/sealed-browser').exists())
            self.assertEqual([reason for _, _, reason in report], ['idle job output'])

    def test_receipts_keep_small_records_and_payloads_only_where_needed(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            receipts = root / 'Build/production-build/receipts'
            names = [f'20261107-0000{index:02d}-{index:08x}' for index in range(25)]
            for name in names:
                write(receipts / name / 'result.json', name.encode())
                write(receipts / name / 'generated/Vox.c')
                write(receipts / name / 'frozen-compiler-inputs/0-Vox.c.i')
            published = names[2]
            write(root / 'Build/production-build/latest.json', published.encode())
            prune_build.prune_receipts(root / 'Build')
            kept = sorted(path.name for path in receipts.iterdir())
            self.assertEqual(kept, sorted([published] + names[-20:]))
            for name in kept:
                has_payload = (receipts / name / 'generated').exists()
                self.assertEqual(has_payload, name in (published, names[-1]), name)
                self.assertEqual((receipts / name / 'frozen-compiler-inputs').exists(), has_payload)
                self.assertTrue((receipts / name / 'result.json').exists())

    def test_runtime_caches_keep_recent_digests_and_retire_stale_ones(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            cache = root / 'Build/v/prealloc-runtime'
            for index in range(5):
                digest = write(cache / f'digest{index}/builtin/builtin.v').parent.parent
                write(cache / f'digest{index}.lock')
                age(digest, OLD - index * 3600)
            age(cache / 'digest4', time.time())
            self.prune(root, held={cache / 'digest3'})
            remaining = sorted(path.name for path in cache.iterdir())
            # digest4 is fresh, digest0 is the next most recent, digest3 is held.
            self.assertEqual(remaining, ['digest0', 'digest0.lock', 'digest3', 'digest3.lock',
                                         'digest4', 'digest4.lock'])

    def test_dry_run_reports_without_removing(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            write(root / 'Build/old/result.json', b'x' * 10000)
            age(root / 'Build/old')
            report = self.prune(root, dry_run=True)
            self.assertEqual([Path(path).name for _, path, _ in report], ['old'])
            self.assertTrue((root / 'Build/old/result.json').exists())


if __name__ == '__main__':
    unittest.main()
