import unittest

from wpt_inventory import inventory_manifest


class InventoryTests(unittest.TestCase):
    def test_counts_generated_variants_without_counting_references_or_support(self):
        manifest = dict(version=9, url_base='/', items={
            'testharness': {'workers': {'a.any.js': ['hash',
                ['workers/a.any.html', {}],
                ['workers/a.any.worker.html?mode=one', {}],
                ['workers/a.any.worker.html?mode=two', {}]],
                'b.html': ['hash', [None, {}]]}},
            'reftest': {'r.html': ['hash', [None,
                [['/one-ref.html', '=='], ['/two-ref.html', '!=']], {}]]},
            'manual': {'m.html': ['hash', [None, {}]]},
            'wdspec': {'test_driver.py': ['hash', [None, {}]]},
            'support': {'one-ref.html': ['hash', []], 'helper.py': ['hash', []]},
            'spec': {'META.yml': ['hash', [None, {'spec_link1': 'https://example.test/'}]]}})
        result, urls = inventory_manifest(manifest)
        self.assertEqual(result['manifest_source_files'], 8)
        self.assertEqual(result['test_source_files'], 5)
        self.assertEqual(result['test_variants'], 7)
        self.assertEqual(result['types']['testharness'], dict(source_files=2, test_variants=4))
        self.assertEqual(result['types']['reftest']['test_variants'], 1)
        self.assertEqual(result['types']['support']['test_variants'], 0)
        self.assertIsNone(result['subtests'])
        self.assertEqual(urls, {'/workers/a.any.html', '/workers/a.any.worker.html?mode=one',
                                '/workers/a.any.worker.html?mode=two', '/workers/b.html'})

    def test_retains_new_test_types_in_the_inventory(self):
        result, _ = inventory_manifest(dict(version=9, url_base='/', items={
            'new-type': {'test.html': ['hash', [None, {}]]}}))
        self.assertEqual(result['types']['new-type']['test_variants'], 1)
        self.assertEqual(result['test_variants'], 1)

    def test_rejects_partial_or_unrecognized_manifest_formats(self):
        for manifest in (
                dict(version=8, url_base='/', items={}),
                dict(version=9, url_base='/subset/', items={}),
                dict(version=9, url_base='/', items={'testharness': {'a.html': ['hash']}}),
                dict(version=9, url_base='/', items={'testharness': {'a.html': ['hash', 'bad']}})):
            with self.subTest(manifest=manifest), self.assertRaises(ValueError):
                inventory_manifest(manifest)


if __name__ == '__main__':
    unittest.main()
