"""Keep generated CSS lookup dispatch bounded without changing name tables."""
import importlib.util
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


def lookup_rows(source, result):
    return re.findall(r"'([^']+)'\s*\{\s*value = " + result
                      + r"\.([a-z0-9_]+)\s+found = true\s*\}", source)


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CSSNameDispatchTests(unittest.TestCase):
    def test_generators_preserve_every_row_and_partition_by_length_and_first_byte(self):
        rows = [('auto', 'auto'), ('none', 'none_'), ('normal', 'normal'),
                ('-infinity', 'negative_infinity'), ('inherit', 'inherit')]
        outputs = []
        for tool in ['generate_css_keywords', 'generate_css_calculation_metadata']:
            output = load(tool).dispatched_lookup(rows, 'name', 'Keyword')
            outputs.append(output)
            self.assertEqual(sorted(lookup_rows(output, 'Keyword')), sorted(rows))
            self.assertIn('match name.len {', output)
            self.assertIn('match name[0] {', output)
            self.assertLess(output.index('match name.len {'), output.index('match name[0] {'))
            self.assertNotIn('map[', output)
            self.assertNotIn('__global', output)
        self.assertEqual(outputs[0], outputs[1])

    def test_keyword_dispatch_reproduces_current_complete_mapping(self):
        source = (ROOT / 'css/style_values_core.v').read_text()
        start = source.index('pub fn keyword_from_string(')
        end = source.index('// --- StyleValue ---', start)
        body = source[start:end]
        rows = lookup_rows(body, 'Keyword')
        self.assertGreater(len(rows), 800)
        generated = load('generate_css_keywords').dispatched_lookup(rows, 'name', 'Keyword')
        self.assertEqual(sorted(rows), sorted(lookup_rows(generated, 'Keyword')))

    def test_dispatch_is_independent_of_input_order_and_preserves_the_caller_rows(self):
        rows = [('inherit', 'inherit'), ('inline', 'inline_'), ('initial', 'initial'),
                ('inside', 'inside'), ('invert', 'invert')]
        original = rows.copy()
        for name in ['generate_css_keywords', 'generate_css_calculation_metadata']:
            tool = load(name)
            forward = tool.dispatched_lookup(rows, 'name', 'Keyword')
            reverse = tool.dispatched_lookup(list(reversed(rows)), 'name', 'Keyword')
            self.assertEqual(forward, reverse)
            self.assertEqual(rows, original)
            self.assertEqual(sorted(lookup_rows(forward, 'Keyword')), sorted(rows))

    def test_empty_dispatch_returns_none_without_reading_an_initial_byte(self):
        for name in ['generate_css_keywords', 'generate_css_calculation_metadata']:
            output = load(name).dispatched_lookup([], 'name', 'Keyword')
            self.assertEqual(output, '\treturn none\n')

    def test_property_generator_uses_identical_dispatch_without_legacy_alias_entries(self):
        tool = load('generate_css_calculation_metadata')
        definition = {'initial': 'auto', 'animation-type': 'by-computed-value',
                      'requires-computation': 'cascaded-value'}
        source = tool.generate({'width': definition, 'height': definition,
                                'word-wrap': {'legacy-alias-for': 'width'}}, {})
        start = source.index('fn property_id_from_canonical_name(')
        end = source.index('pub fn string_from_property_id(', start)
        body = source[start:end]
        self.assertIn(tool.dispatched_lookup([('width', 'width'), ('height', 'height')], 'name', 'PropertyID'), body)
        self.assertNotIn('word-wrap', body)
        self.assertIn("'word-wrap'", source[:start])


if __name__ == '__main__':
    unittest.main()
