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

    def test_all_shorthand_contains_each_longhand_extension_once(self):
        tables = {
            'longhands_for_shorthand': [('all', ['color'])],
            'expanded_longhands_for_shorthand': [('all', ['color'])],
            'shorthands_for_longhand': [('color', ['all'])],
        }
        extend_shorthand_tables(extend_shorthand_tables(tables))
        expected = ['color', 'font_synthesis_position', 'font_synthesis_small_caps',
                    'font_synthesis_style', 'font_synthesis_weight', 'hyphens',
                    'text_box_edge', 'text_box_trim']
        self.assertEqual(tables['longhands_for_shorthand'][0][1], expected)
        self.assertEqual(tables['expanded_longhands_for_shorthand'][0][1], expected)
        reverse = dict(tables['shorthands_for_longhand'])
        self.assertEqual(len(reverse), len(tables['shorthands_for_longhand']))
        for name in expected:
            self.assertEqual(reverse[name].count('all'), 1)
        self.assertEqual(reverse['text_box_trim'], ['all'])
        self.assertEqual(reverse['text_box_edge'], ['all'])
        self.assertNotIn('font_synthesis', expected)

        ordered = {
            'longhands_for_shorthand': [('all', ['webkit_font_smoothing', 'height', 'image_rendering'])],
            'expanded_longhands_for_shorthand': [('all', ['height', 'image_rendering'])],
            'shorthands_for_longhand': [],
        }
        extend_shorthand_tables(ordered)
        self.assertEqual(ordered['longhands_for_shorthand'][0][1],
                         ['webkit_font_smoothing', *expected[1:5], 'height', 'hyphens',
                          'image_rendering', 'text_box_edge', 'text_box_trim'])


if __name__ == '__main__':
    unittest.main()
