import copy
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from check_catalog_replay import TITLE, compare_pixels, load_cases, sha, validate_document


class CatalogReplayTests(unittest.TestCase):
    def setUp(self):
        self.metadata = dict(url='https://boards.4chan.org/pol/catalog', width=1024,
                             height=768, scroll_y=768, scroll_height=14457, board_title_y=-614)
        self.audit = dict(url=self.metadata['url'], title=TITLE, ready='complete',
                          viewport_width=1024, viewport_height=768, selections=[
                              dict(selector='html', elements=[dict(rect=dict(y=-768, height=14457))]),
                              dict(selector='.thread', count=201),
                              dict(selector='.boardTitle', elements=[dict(rect=dict(y=-614))]),
                              dict(selector='.thumb', elements=[dict(image=dict(
                                  complete=True, natural_width=150)) for _ in range(8)])])

    def test_error_pages_and_incomplete_catalogs_are_rejected(self):
        validate_document(self.audit, self.metadata)
        for field, value in [('title', 'Navigation error'), ('ready', 'interactive'),
                             ('url', 'about:blank'), ('viewport_height', 700)]:
            with self.subTest(field=field):
                audit = dict(self.audit, **{field: value})
                with self.assertRaises(ValueError):
                    validate_document(audit, self.metadata)
        self.audit['selections'][1]['count'] = 0
        with self.assertRaises(ValueError):
            validate_document(self.audit, self.metadata)

    def test_stationary_or_truncated_documents_are_rejected(self):
        self.audit['selections'][0]['elements'][0]['rect']['height'] = 14457.7109375
        validate_document(self.audit, self.metadata)
        audit = copy.deepcopy(self.audit)
        audit['selections'][2]['elements'][0]['rect']['y'] = 154
        with self.assertRaises(ValueError):
            validate_document(audit, self.metadata)
        for height in [768, 14458]:
            audit = copy.deepcopy(self.audit)
            audit['selections'][0]['elements'][0]['rect']['height'] = height
            with self.assertRaises(ValueError):
                validate_document(audit, self.metadata)

    def test_incomplete_thumbnails_are_rejected(self):
        self.audit['selections'][3]['elements'][0]['image']['complete'] = False
        with self.assertRaises(ValueError):
            validate_document(self.audit, self.metadata)

    def test_pixel_gate_rejects_one_rgb_or_alpha_difference(self):
        with tempfile.TemporaryDirectory() as directory:
            expected, actual, diff = [Path(directory) / name
                                      for name in ['expected.png', 'actual.png', 'diff.png']]
            Image.new('RGBA', (2, 2), (10, 20, 30, 255)).save(expected)
            for pixel, count in [((10, 20, 30, 255), 0), ((11, 20, 30, 255), 1),
                                 ((10, 20, 30, 254), 1)]:
                with self.subTest(pixel=pixel):
                    with Image.open(expected) as image:
                        image.putpixel((1, 1), pixel)
                        image.save(actual)
                    result = compare_pixels(expected, actual, diff)
                    self.assertEqual(result, dict(differing_pixels=count, total_pixels=4))
            Image.new('RGBA', (1, 1)).save(actual)
            with self.assertRaises(ValueError):
                compare_pixels(expected, actual, diff)

    def test_reference_gate_rejects_changed_images_and_unknown_cases(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / 'reference.png'
            Image.new('RGBA', (2, 2)).save(image)
            receipt = dict(strict_controlled_catalog_pixels_pass=True, checks=[dict(
                name='catalog-scroll-0', reference=str(image), reference_sha256=sha(image))])
            self.assertEqual(len(load_cases(receipt, [])), 1)
            with self.assertRaises(ValueError):
                load_cases(receipt, ['catalog-scroll-768'])
            Image.new('RGBA', (2, 2), 'white').save(image)
            with self.assertRaises(ValueError):
                load_cases(receipt, [])


if __name__ == '__main__':
    unittest.main()
