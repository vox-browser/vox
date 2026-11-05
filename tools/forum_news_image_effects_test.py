import tempfile
from pathlib import Path
from unittest import TestCase, mock

import forum_news_image_effects as effects
from page_archive import load_archive


class ImageEffectsArchiveTests(TestCase):
    def test_root_origin_seed_keeps_the_authored_page_and_original_publisher_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            seed = Path(temporary) / 'seed'
            effects.create_seed(seed, 'root-origin')
            manifest = load_archive(seed)
            self.assertEqual(manifest['url'], effects.ROOT_URL)
            self.assertEqual(set(manifest['responses']), {effects.ROOT_URL, effects.IMAGE_URL})
            document = manifest['responses'][effects.ROOT_URL]
            self.assertEqual((seed / 'bodies' / document['sha256']).read_bytes(),
                             effects.ROOT_FIXTURE.read_bytes())
            self.assertEqual(manifest['responses'][effects.IMAGE_URL]['sha256'], effects.IMAGE_SHA256)

    def test_seed_replays_the_exact_http_image_bytes_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            seed = Path(temporary) / 'seed'
            effects.create_seed(seed)
            manifest = load_archive(seed)
            self.assertEqual(manifest['url'], effects.URL)
            self.assertEqual(set(manifest['responses']), {effects.URL, effects.IMAGE_URL})
            image = manifest['responses'][effects.IMAGE_URL]
            self.assertEqual(image['sha256'], effects.IMAGE_SHA256)
            self.assertEqual((seed / 'bodies' / image['sha256']).read_bytes(), effects.IMAGE.read_bytes())
            with self.assertRaises(FileExistsError):
                effects.create_seed(seed)

    def test_changed_encoded_publisher_response_is_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as temporary:
            seed = Path(temporary) / 'seed'
            with mock.patch.object(effects, 'IMAGE_SHA256', '0' * 64):
                with self.assertRaisesRegex(RuntimeError, 'original encoded'):
                    effects.create_seed(seed)
            self.assertFalse(seed.exists())
