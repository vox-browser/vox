module libjs

fn test_direct_frame_clearing_preserves_array_alias_and_reset_semantics() {
	defer { set_direct_frame_clears_for_testing(true) }
	for length in [0, 1, 2, 7, 16, 65] {
		mut cleared := [][]Value{}
		mut aliases := [][]Value{}
		for enabled in [false, true] {
			set_direct_frame_clears_for_testing(enabled)
			mut context := ExecutionContext{
				values:          []Value{len: length, init: Value.from_i32(i32(index + 10))}
				frame_id:        42
				program_counter: 7
				argument_count:  u32(length)
			}
			alias := context.values[..]
			context.clear_for_reuse()
			assert context.frame_id == 0 && context.program_counter == 0 && context.argument_count == 0
			assert context.reusable && context.function == none && context.realm == none
			for value in context.values {
				assert value.is_undefined()
			}
			cleared << context.values.clone()
			aliases << alias.clone()
		}
		assert cleared[0] == cleared[1]
		assert aliases[0] == aliases[1]
	}
}
