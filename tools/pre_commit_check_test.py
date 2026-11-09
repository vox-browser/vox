from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest

import pre_commit_check

CHECK = Path(__file__).resolve().parent / 'pre_commit_check.py'


class PreCommitCheckTests(unittest.TestCase):
    def repository(self, directory):
        root = Path(directory)
        subprocess.run(['git', 'init', '-q', '-b', 'master', str(root)], check=True)
        subprocess.run(['git', '-C', str(root), 'config', 'user.email', 'test@example.test'], check=True)
        subprocess.run(['git', '-C', str(root), 'config', 'user.name', 'Test'], check=True)
        return root

    def stage(self, root, path, data=b'data', force=True):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        subprocess.run(['git', '-C', str(root), 'add'] + (['-f'] if force else []) + [path], check=True)

    def commit(self, root, message='commit'):
        subprocess.run(['git', '-C', str(root), 'commit', '-q', '--no-verify', '-m', message], check=True)

    def test_source_reports_and_allowed_assets_pass(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            for path in ['layout/grid.v', 'docs/REPORT.md', 'docs/performance/cohort.md',
                         'docs/manifests/fixture.json', 'Tests/Browser/config.json',
                         'adblock/engine.js.gz', 'tools/adblock/fixtures/page.json.gz',
                         'Tests/Browser/Brave/candidates/page.zip']:
                self.stage(root, path)
            self.assertEqual(pre_commit_check.violations(root), [])

    def test_force_added_measurement_dumps_are_rejected(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            paths = ['docs/performance/github-vlang-instruction-diagnostics-20261108-20pct.json',
                     'docs/performance/raw/cohort.jsonl', 'docs/performance/raw/events.ndjson',
                     'docs/benchmark-results/cohort.json', 'docs/performance/diagnostics.JSON']
            for path in paths:
                self.stage(root, path)
            problems = pre_commit_check.violations(root)
            self.assertEqual(len(problems), len(paths), problems)
            self.assertTrue(all('measurement dumps stay local' in problem for problem in problems))

    def test_tracked_measurement_updates_are_rejected_and_untracking_keeps_local_data(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            path = 'docs/performance/existing-diagnostic.json'
            self.stage(root, path, b'original')
            self.commit(root)
            self.stage(root, path, b'local measurement update')
            self.assertEqual(pre_commit_check.violations(root),
                             [f'{path}: measurement dumps stay local; commit a Markdown summary instead'])
            subprocess.run(['git', '-C', str(root), 'rm', '-q', '--cached', path], check=True)
            self.assertEqual((root / path).read_bytes(), b'local measurement update')
            self.assertEqual(pre_commit_check.violations(root), [])

    def test_repository_ignore_rules_cover_generated_measurements(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            (root / '.gitignore').write_bytes((CHECK.parent.parent / '.gitignore').read_bytes())
            paths = ['docs/performance/github-vlang-instruction-diagnostics-20261108-20pct.json',
                     'docs/performance/raw/nested/cohort.json', 'docs/performance/raw/cohort.jsonl',
                     'docs/performance/events.ndjson', 'docs/benchmark-results/cohort.json']
            for path in paths:
                result = subprocess.run(['git', '-C', str(root), 'check-ignore', path],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, path)
            self.stage(root, paths[0])
            self.assertIn('measurement dumps stay local', pre_commit_check.violations(root)[0])

    def test_archives_outside_asset_directories_are_rejected(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            for path in ['docs/performance/raw/cohort.tar.gz', 'docs/evidence/run.zip',
                         'tools/evidence.TGZ', 'Tests/Browser/run.tar.zst']:
                self.stage(root, path)
            problems = pre_commit_check.violations(root)
            self.assertEqual(len(problems), 4, problems)
            self.assertTrue(all('archives stay local' in problem for problem in problems))

    def test_build_output_is_rejected(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            self.stage(root, 'Build/session/result.json')
            self.assertEqual(pre_commit_check.violations(root),
                             ['Build/session/result.json: Build/ is local scratch'])

    def test_oversized_files_are_rejected(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            self.stage(root, 'docs/huge.json', b'x' * 2048)
            self.stage(root, 'docs/small.json', b'x' * 10)
            problems = pre_commit_check.violations(root, max_bytes=1024)
            self.assertEqual(len(problems), 1)
            self.assertTrue(problems[0].startswith('docs/huge.json:'))

    def test_renaming_an_archive_into_docs_is_rejected_and_removal_is_allowed(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            self.stage(root, 'adblock/old.gz')
            self.stage(root, 'docs/raw/old-evidence.zip')
            self.commit(root)
            subprocess.run(['git', '-C', str(root), 'mv', 'adblock/old.gz', 'docs/old.gz'], check=True)
            subprocess.run(['git', '-C', str(root), 'rm', '-q', 'docs/raw/old-evidence.zip'], check=True)
            problems = pre_commit_check.violations(root)
            self.assertEqual(problems, ['docs/old.gz: archives stay local; commit the report or manifest instead'])

    def test_the_hook_entry_point_blocks_the_commit(self):
        with TemporaryDirectory() as directory:
            root = self.repository(directory)
            self.stage(root, 'docs/evidence.tar.gz')
            result = subprocess.run([sys.executable, str(CHECK)], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn('docs/evidence.tar.gz', result.stderr)
            subprocess.run(['git', '-C', str(root), 'rm', '-q', '--cached', 'docs/evidence.tar.gz'], check=True)
            self.stage(root, 'docs/REPORT.md')
            result = subprocess.run([sys.executable, str(CHECK)], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
