#!/usr/bin/env python3
import unittest

import prune_stale_launchservices as prune

DUMP = '\n'.join([
    'Checking data integrity......done.',
    prune.SEPARATOR,
    'bundle id:                  1234',
    'path:                       /Users/me/Build/old/Vox.app (0x89c8)',
    'name:                       Vox',
    'identifier:                 org.ladybirdbrowser.vox',
    prune.SEPARATOR,
    'bundle id:                  1235',
    'path:                       /Users/me/Build/v/Vox.app (0x89ca)',
    'identifier:                 org.ladybirdbrowser.vox',
    prune.SEPARATOR,
    'bundle id:                  1236',
    'path:                       /Volumes/Gone/Other.app (0x8a00)',
    'identifier:                 com.example.other',
    prune.SEPARATOR,
    'claim id:                   99',
    'path:                       /not/a/bundle/record (0x1)',
    prune.SEPARATOR,
    'bundle id:                  1237',
    'path:                       /Users/me/Build/old/Vox.app (0x89c8)',
    'identifier:                 org.ladybirdbrowser.vox',
])


class PruneStaleLaunchServicesTest(unittest.TestCase):
    def test_reports_each_missing_bundle_path_once_and_keeps_existing_bundles(self):
        existing = {'/Users/me/Build/v/Vox.app'}
        stale = prune.stale_records(DUMP, exists=lambda path: path in existing)
        self.assertEqual(stale, [
            dict(path='/Users/me/Build/old/Vox.app', identifier='org.ladybirdbrowser.vox'),
            dict(path='/Volumes/Gone/Other.app', identifier='com.example.other'),
        ])

    def test_ignores_records_without_bundle_identity(self):
        paths = [path for path, _ in prune.bundle_records(DUMP)]
        self.assertNotIn('/not/a/bundle/record', paths)


if __name__ == '__main__':
    unittest.main()
