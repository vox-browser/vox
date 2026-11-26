import unittest
from pathlib import Path
import tempfile
from build_hn_engine_benchmark import benchmark_entry, profile_array_return_compat


class BenchmarkEntryTests(unittest.TestCase):
    def test_sources_remain_canonical_and_existing_links_are_reusable(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            (root / 'v.mod').write_text('Module {}')
            (root / 'main.v').write_text('module main')
            source = root / 'sites/example_test.v'
            source.parent.mkdir()
            source.write_text('module main')
            entry = benchmark_entry(root, source)
            self.assertTrue(entry.is_symlink())
            self.assertEqual(entry.resolve(), source)
            self.assertEqual((entry.parent / 'main.v').resolve(), root / 'main.v')
            self.assertEqual(benchmark_entry(root, source), entry)
            self.assertFalse((entry.parent / 'Build').exists())

    def test_external_source_and_regular_file_collision_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'repo'
            root.mkdir()
            external = Path(temp) / 'external_test.v'
            external.write_text('module main')
            with self.assertRaises(ValueError):
                benchmark_entry(root, external)
            source = root / 'example_test.v'
            source.write_text('module main')
            directory = root / 'Build/v/address-bar-tests'
            directory.mkdir(parents=True)
            (directory / source.name).write_text('keep')
            with self.assertRaises(ValueError):
                benchmark_entry(root, source)
            self.assertEqual((directory / source.name).read_text(), 'keep')


class ProfileArrayReturnTests(unittest.TestCase):
    def test_named_array_members_preserve_both_tuple_orders(self):
        prefix = '(multi_return_Array_fixed_canvas__Rect_2_Array_fixed_int_2)'
        for a, b in [('first', 'second'), ('second', 'first')]:
            with self.subTest(a=a):
                original = prefix + '{\t(canvas__Rect[2]){' + a + '.rect, ' + b + '.rect},\n (int[2]){' + a + '.dir, ' + b + '.dir}}'
                fixed, count = profile_array_return_compat(original)
                self.assertEqual(count, 1)
                self.assertEqual(fixed, prefix + '{.arg0={' + a + '.rect, ' + b + '.rect}, .arg1={' + a + '.dir, ' + b + '.dir}}')
                self.assertEqual(profile_array_return_compat(fixed), (fixed, 0))

    def test_other_types_and_array_expressions_remain_unchanged(self):
        source = '(other_tuple){(canvas__Rect[2]){a.rect,b.rect},(int[2]){a.dir,b.dir}}'
        self.assertEqual(profile_array_return_compat(source), (source, 0))
