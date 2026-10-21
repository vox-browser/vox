module css

import platform

fn test_public_component_parser_still_snapshots_caller_slots() {
	mut values := parse_component_values_for_value_logic('17px')
	mut parser := Parser.from_component_values(values)
	values[0] = ComponentValue.from_token(Token.create_dimension_from_double(23, 'px', '23px'))
	assert parser.parse_css_value(.width)?.serialize(.normal) == '17px'
	mut replacement := Parser.from_component_span(values)
	assert replacement.parse_css_value(.width)?.serialize(.normal) == '23px'
}

fn test_component_span_parsing_keeps_nested_input_unchanged_after_success_and_failure() {
	for source in ['calc(2px + 3em)', 'var(--size, calc(2px + 3em))', 'bad(17px)'] {
		values := parse_component_values_for_value_logic(source)
		before := parser_component_values_to_string(values)
		mut snapshot := Parser.from_component_values(values)
		expected := snapshot.parse_css_value(.width)
		for _ in 0 .. 3 {
			mut parser := Parser.from_component_span(values)
			actual := parser.parse_css_value(.width)
			if value := expected {
				assert actual?.serialize(.normal) == value.serialize(.normal)
			} else {
				assert actual == none
			}
			assert parser_component_values_to_string(values) == before
		}
	}
}

fn test_repeated_component_span_parses_do_not_retain_an_input_sized_copy() {
	$if !prealloc { return }
	// Separate whitespace components are valid syntax and make the input much
	// larger than the scalar result, exposing redundant parser input copies.
	space := ComponentValue.from_token(Token.create_whitespace(' '))
	mut values := []ComponentValue{len: 8193, init: space}
	values[values.len - 1] = ComponentValue.from_token(Token.create_dimension_from_double(29, 'px', '29px'))
	mut warm := Parser.from_component_span(values)
	assert warm.parse_css_value(.width)?.serialize(.normal) == '29px'
	mut storage := platform.new_arena('component span parses')
	entry := storage.enter()
	for _ in 0 .. 64 {
		mut parser := Parser.from_component_span(values)
		assert parser.parse_css_value(.width)?.serialize(.normal) == '29px'
	}
	storage.leave(entry)
	assert storage.usage().used < i64(sizeof(ComponentValue)) * values.len * 8
	storage.release()
	assert values[0].is(.whitespace)
	assert values.last().token().dimension_value() == 29
}
