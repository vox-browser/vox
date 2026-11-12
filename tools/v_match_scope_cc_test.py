import unittest

from prepare_v_match_scope import needs_fix
from v_match_scope_cc import patch_compiler


class MatchScopeCompatibilityTests(unittest.TestCase):
    def source(self, prefix='transform__Transformer'):
        return f'''void {prefix}__lower_remaining_matches_in_used_fns({prefix}* t) {{
    string old_file = t->cur_file;
    for (int i = 0; i < 2; ++i) {{
        epoch++;
        lower_body(t, i);
    }}
    t->cur_file = old_file;
}}
'''

    def test_patch_preserves_outer_scope_and_seeds_each_function_before_lowering(self):
        for prefix in ('transform__Transformer', 'v__transform__Transformer'):
            source, found = patch_compiler(self.source(prefix))
            self.assertTrue(found)
            self.assertLess(source.index('__detach_function_local_state'), source.index('for ('))
            self.assertLess(source.index('__seed_generated_fn_body_context'), source.index('lower_body'))
            self.assertGreater(source.index('__restore_function_local_state'), source.index('lower_body'))
            self.assertIn('t->cur_fn_name = vox_outer_match_fn;', source)
            self.assertIn('__set_cur_fn_ret_type(t, vox_outer_match_ret)', source)
            self.assertEqual(patch_compiler(source), (source, True))

    def test_other_native_units_remain_byte_identical(self):
        source = 'int helper(void) { return 42; }\n'
        self.assertEqual(patch_compiler(source), (source, False))

    def test_changed_or_ambiguous_compiler_shape_fails_closed(self):
        for source in (self.source().replace('epoch++;', 'epoch += 1;'), self.source() * 2):
            with self.assertRaises(RuntimeError):
                patch_compiler(source)

    def test_upstream_scope_fix_avoids_a_bootstrap(self):
        signature = 'fn (mut t Transformer) lower_remaining_matches_in_used_fns() {'
        self.assertTrue(needs_fix(signature + '\n t.lower_body()\n}'))
        self.assertFalse(needs_fix(signature + '\n t.seed_generated_fn_body_context(id)\n}'))
        self.assertFalse(needs_fix('module legacy_compiler'))


if __name__ == '__main__':
    unittest.main()
