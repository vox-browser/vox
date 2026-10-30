import unittest

from css_translation_extensions import extend_properties, extend_shorthand_tables, KEYWORDS


class TranslationPropertyExtensionsTests(unittest.TestCase):
    def test_hyphens_metadata_retains_an_upstream_definition_when_it_arrives(self):
        extensions = extend_properties({})
        self.assertEqual(extensions['hyphens']['initial'], 'manual')
        self.assertTrue(extensions['hyphens']['inherited'])
        self.assertNotIn('-webkit-hyphens', extensions)
        upstream = {'hyphens': {'initial': 'upstream'}}
        self.assertEqual(extend_properties(upstream)['hyphens'], upstream['hyphens'])
        self.assertIn('manual', KEYWORDS)

    def test_all_shorthand_contains_the_extension_once_and_skips_its_alias(self):
        tables = {
            'longhands_for_shorthand': [('all', ['color'])],
            'expanded_longhands_for_shorthand': [('all', ['color'])],
            'shorthands_for_longhand': [('color', ['all'])],
        }
        extend_shorthand_tables(extend_shorthand_tables(tables))
        self.assertEqual(tables['longhands_for_shorthand'][0][1], ['color', 'hyphens'])
        self.assertEqual(tables['expanded_longhands_for_shorthand'][0][1], ['color', 'hyphens'])
        self.assertEqual(tables['shorthands_for_longhand'], [('color', ['all']), ('hyphens', ['all'])])

        ordered = {
            'longhands_for_shorthand': [('all', ['webkit_font_smoothing', 'height', 'image_rendering'])],
            'expanded_longhands_for_shorthand': [('all', ['height', 'image_rendering'])],
            'shorthands_for_longhand': [],
        }
        extend_shorthand_tables(ordered)
        self.assertEqual(ordered['longhands_for_shorthand'][0][1],
                         ['webkit_font_smoothing', 'height', 'hyphens', 'image_rendering'])


if __name__ == '__main__':
    unittest.main()
