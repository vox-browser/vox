module css

import platform

fn test_component_source_serialization_preserves_spelling_after_input_retirement() {
	for source in [r'var(--size, calc(2px/**/ + 3%))',
		r'outer([a/**/b], {--label: "中\\20 text"})', r'outer([unclosed'] {
		input := platform.begin_thread_scratch('component serialization test input')
		values := parse_component_values_for_value_logic(source)
		input.leave()
		actual := parser_component_values_original_text(values)
		input.finish()
		assert actual == source
	}
}

fn test_component_source_serialization_retains_only_final_text() {
	source := 'outer([' + 'calc(2px/**/ + 3%) '.repeat(2048) + '], "中")'
	values := parse_component_values_for_value_logic(source)
	before := platform.thread_arena_usage().used
	actual := parser_component_values_original_text(values)
	$if prealloc {
		assert platform.thread_arena_usage().used - before < source.len + 1024
	}
	assert actual == source
	assert parser_component_values_original_text([]ComponentValue{}) == ''
}
