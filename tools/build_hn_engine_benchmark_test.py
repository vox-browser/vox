import unittest
from build_hn_engine_benchmark import profile_array_return_compat


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
