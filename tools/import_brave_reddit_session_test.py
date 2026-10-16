import sqlite3
from pathlib import Path
import tempfile
import unittest

from import_brave_reddit_session import copy_reddit_database, reddit_cookie_lines


def cookie(domain='.reddit.com', **overrides):
    return dict(domain=domain, path='/', secure=True, httpOnly=True,
                session=True, expires=-1, name='reddit_session', value='fixture', **overrides)


class RedditSessionImportTests(unittest.TestCase):
    def test_cookie_export_excludes_other_sites_and_partitioned_or_expired_entries(self):
        cookies = [cookie(), cookie('old.reddit.com'), cookie('.notreddit.com'),
                   cookie('.reddit.com.evil.test'), cookie(partitionKey={'topLevelSite': 'https://other.test'}),
                   cookie(partitionKeyOpaque=True)]
        expired = cookie()
        expired.update(session=False, expires=1)
        cookies.append(expired)
        lines = reddit_cookie_lines(cookies)
        self.assertEqual(lines[1:], [
            '#HttpOnly_.reddit.com\tTRUE\t/\tTRUE\t0\treddit_session\tfixture',
            '#HttpOnly_old.reddit.com\tFALSE\t/\tTRUE\t0\treddit_session\tfixture'])

    def test_control_characters_cannot_create_cookie_rows(self):
        for field in ['domain', 'path', 'name', 'value']:
            entry = cookie()
            entry[field] = ('/\n' if field == 'path' else 'bad\tvalue')
            if field == 'domain':
                entry[field] = 'bad\t.reddit.com'
            with self.assertRaises(ValueError):
                reddit_cookie_lines([entry])

    def test_profile_copy_contains_only_reddit_and_leaves_source_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / 'source', Path(directory) / 'Cookies'
            with sqlite3.connect(source) as database:
                database.execute('CREATE TABLE cookies(host_key TEXT, value TEXT)')
                database.executemany('INSERT INTO cookies VALUES(?,?)', [
                    ('.reddit.com', 'fixture'), ('old.reddit.com', 'fixture'),
                    ('reddit.com', 'fixture'), ('notreddit.com', 'unrelated'),
                    ('reddit.com.evil.test', 'unrelated')])
            before = source.read_bytes()
            copy_reddit_database(source, destination)
            self.assertEqual(source.read_bytes(), before)
            with sqlite3.connect(destination) as database:
                hosts = database.execute('SELECT host_key FROM cookies ORDER BY host_key').fetchall()
            self.assertEqual(hosts, [('.reddit.com',), ('old.reddit.com',), ('reddit.com',)])


if __name__ == '__main__':
    unittest.main()
