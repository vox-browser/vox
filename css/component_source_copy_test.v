module css

import platform

fn test_exact_component_source_copy_preserves_recursive_spelling_and_empty_components() {
	if disable_exact_component_source_copy || disable_flat_component_source { return }
	for source in ['12px', 'a/**/b', '\\31 name + 日本語', 'var(--name, [rgb(1 2 3 / .5)])',
		'url("a b")', 'fn([unfinished', '  red !important  '] {
		values := parse_component_values_for_value_logic(source)
		actual := exact_component_source_copy(values) or { panic('copy declined') }
		assert actual == assemble_component_values_original_text(values)
		assert parser_component_values_original_text(values) == actual
	}
	values := [ComponentValue.new('raw 日本語'),
		ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{}),
		ComponentValue.from_token(Token{type_: .end_of_file})]
	assert exact_component_source_copy(values)? == 'raw 日本語'
	assert exact_component_source_copy([]ComponentValue{})? == ''
}

fn test_exact_component_source_copy_outlives_the_producer_for_single_and_nested_values() {
	if disable_exact_component_source_copy || disable_flat_component_source { return }
	mut owner := platform.new_retained_arena('exact source publication')
	mut retained := owner.enter()
	for source in ['17px', 'fn([日本語], var(--x, "a b"))'] {
		work := platform.begin_thread_scratch('component source producer')
		values := parse_component_values_for_value_logic(source.clone())
		work.leave()
		actual := exact_component_source_copy(values) or { panic('copy declined') }
		work.finish()
		churn := platform.begin_thread_scratch('component source overwrite')
		_ = []u8{len: 256 * 1024, init: u8(0xa5)}
		churn.finish()
		gc_collect()
		assert actual == source
		assert unsafe { actual.str[actual.len] } == 0
		$if prealloc { assert owner.arena.contains(voidptr(actual.str)) }
	}
	retained.finish()
	owner.release()
}

fn test_exact_component_source_size_overflow_keeps_the_original_fallback_available() {
	mut count := ComponentSourceByteCount{length: max_i32 - 1}
	assert !count_component_source_piece('ab', mut count)
	assert count.length == max_i32 - 1
	assert count_component_source_piece('a', mut count)
	assert count.length == max_i32
}
