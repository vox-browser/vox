import unittest

from generate_css_compat_metadata import block_end, merge_keywords, merge_properties


class CompatibilityMetadataTest(unittest.TestCase):
    def test_v_block_scanner_ignores_quoted_and_commented_braces(self):
        source = "{ '}' /* } */ { x } // }\n } tail"
        self.assertEqual(source[block_end(source, 0):], ' tail')

    def test_stale_upstream_cannot_remove_translated_properties_or_override_defaults(self):
        current = {'calculation': """module css
fn property_id_from_canonical_name(name string) ?PropertyID {
\treturn none
}
pub fn string_from_property_id(property_id PropertyID) string {
\treturn match property_id {
\t\t.legacy { 'legacy' }
\t}
}
pub fn property_initial_value_string(property_id PropertyID) string {
\treturn match property_id {
\t\t.legacy { 'preserve me' }
\t}
}
""", 'shorthand': ''}
        for function in ['generated_longhands_for_shorthand',
                         'generated_expanded_longhands_for_shorthand',
                         'generated_shorthands_for_longhand']:
            current['shorthand'] += f'''pub fn {function}(property_id PropertyID) []PropertyID {{
\treturn match property_id {{
\t\t.all {{ [.font_style, .translated_extension] }}
\t\telse {{ []PropertyID{{}} }}
\t}}
}}
'''
        generated = {'calculation': """module css
fn property_id_from_canonical_name(name string) ?PropertyID {
\treturn none
}
pub fn string_from_property_id(property_id PropertyID) string {
\treturn match property_id {
\t\t.legacy { 'legacy' }
\t\t.font_synthesis_style { 'font-synthesis-style' }
\t}
}
pub fn property_initial_value_string(property_id PropertyID) string {
\treturn match property_id {
\t\t.legacy { 'stale upstream value' }
\t\t.font_synthesis_style { 'auto' }
\t}
}
""", 'shorthand': current['shorthand']}
        definitions = {'font-synthesis-style': {'initial': 'auto'}}
        result = merge_properties(current, generated, definitions)
        self.assertIn(".legacy { 'preserve me' }", result['calculation'])
        self.assertNotIn('stale upstream value', result['calculation'])
        self.assertIn(".font_synthesis_style { 'auto' }", result['calculation'])
        self.assertIn('.translated_extension', result['shorthand'])
        self.assertEqual(result['shorthand'].count('.font_synthesis_style'), 2)
        self.assertEqual(merge_properties(result, generated, definitions), result)

    def test_new_keyword_preserves_translated_inventory_and_is_idempotent(self):
        current = """pub enum Keyword {
\ttranslated
}
pub fn string_from_keyword(keyword Keyword) string {
\treturn match keyword {
\t\t.translated { 'translated' }
\t}
}
pub fn keyword_from_string(input string) ?Keyword {
\tname := to_ascii_lowercase(input)
\treturn none
}
"""
        generated = """pub fn string_from_keyword(keyword Keyword) string {
\treturn match keyword {
\t\t.oblique_only { 'oblique-only' }
\t}
}
"""
        result = merge_keywords(current, generated, ['oblique-only'])
        self.assertIn(".translated { 'translated' }", result)
        self.assertIn("if name == 'oblique-only' { return .oblique_only }", result)
        self.assertEqual(result.count('\n\toblique_only\n'), 1)
        self.assertEqual(merge_keywords(result, generated, ['oblique-only']), result)


if __name__ == '__main__':
    unittest.main()
