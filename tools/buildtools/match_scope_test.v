module buildtools

fn match_scope_source(prefix string) string {
	return 'void ${prefix}__lower_remaining_matches_in_used_fns(${prefix}* t) {\n    string old_file = t->cur_file;\n    for (int i = 0; i < 2; ++i) {\n        epoch++;\n        lower_body(t, i);\n    }\n    t->cur_file = old_file;\n}\n'
}

fn test_match_scope_patches_definition_after_forward_declarations() ! {
	for prefix in ['transform__Transformer', 'v__transform__Transformer'] {
		prototype := 'void ${prefix}__lower_remaining_matches_in_used_fns(${prefix}* t);\n'
		// Keep arbitrary generated C bytes and repeated declarations unchanged.
		before := 'const char bytes[] = "\xc0\xff";\n' + prototype + prototype
		after := '\nvoid other_function(void) {\n}\n'
		patched, found := patch_match_compiler(before + match_scope_source(prefix) + after)!
		assert found
		assert patched.starts_with(before)
		assert patched.ends_with(after)
		assert patched.contains('${prefix}__detach_function_local_state(t)')
		assert (patched.index('__detach_function_local_state') or { panic('Missing expected generated C fragment') }) < (patched.index('for (') or { panic('Missing expected generated C fragment') })
		assert (patched.index('__seed_generated_fn_body_context') or { panic('Missing expected generated C fragment') }) < (patched.index('epoch++;') or { panic('Missing expected generated C fragment') })
		assert (patched.index('__restore_function_local_state') or { panic('Missing expected generated C fragment') }) > (patched.index('lower_body') or { panic('Missing expected generated C fragment') })
		assert patched.contains('t->cur_fn_name = vox_outer_match_fn;')
		assert patched.contains('${prefix}__set_cur_fn_ret_type(t, vox_outer_match_ret)')
		again, still_found := patch_match_compiler(patched)!
		assert still_found
		assert again == patched
	}
}

fn test_match_scope_leaves_other_units_and_prototypes_unchanged() ! {
	for source in [
		'int helper(void) { return 42; }\n',
		'void transform__Transformer__lower_remaining_matches_in_used_fns(transform__Transformer* t);\n',
	] {
		patched, found := patch_match_compiler(source)!
		assert !found
		assert patched == source
	}
}

fn test_match_scope_rejects_duplicate_definitions_and_unsupported_bodies() {
	source := match_scope_source('transform__Transformer')
	for invalid in [
		source + source,
		source + source.replace('* t)', '* other)'),
		source + match_scope_source('v__transform__Transformer'),
		source.replace('epoch++;', 'epoch += 1;'),
		source.replace('epoch++;', 'epoch++; epoch++;'),
		source.replace('\n}', ''),
	] {
		mut rejected := false
		patch_match_compiler(invalid) or { rejected = true }
		assert rejected
	}
}
