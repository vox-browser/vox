module css

import math
import platform

fn test_dom_integer_lengths_match_css_number_and_unit_serialization() {
	mut retained := []string{}
	mut expected := []string{}
	$for member in LengthUnit.values {
		unit := LengthUnit(member.value)
		for number in [-2147483648.0, -1000.0, -1.0, -0.0, 0.0, 1.0, 24.0, 999999.0, 2147483647.0] {
			value := StyleValue(LengthStyleValue.create(Length.new(number, unit)))
			wrapped := dom_style_value_from_value_logic(value)
			text := wrapped.css_text
			assert text == value.serialize(.normal)
			assert typed_style_value_logic_from_dom(wrapped)?.equals(value)
			retained << text
			expected << value.serialize(.normal)
		}
	}
	// Reuse temporary storage after the serializer returns, exposing pointers
	// that accidentally retain its stack buffer or scratch allocations.
	for _ in 0 .. 32 {
		scratch := platform.begin_thread_scratch('reuse integer length serialization workspace')
		_ = []u8{len: 64 * 1024, init: 0xa5}
		scratch.finish()
	}
	for index, text in retained {
		assert text == expected[index]
	}
}

fn test_dom_fractional_large_and_nonfinite_lengths_keep_general_serialization() {
	for number in [0.00000049, -0.00000049, 0.00000051, -0.00000051, 12.5, 1.2345676, -2147483649.0,
		2147483648.0, 1e100, math.inf(1), math.inf(-1), math.nan()] {
		length := LengthStyleValue.create(Length.make_px(number))
		assert serialize_dom_integer_length(length) == none
		value := StyleValue(length)
		assert serialize_dom_style_value(value) == value.serialize(.normal)
	}
}

fn test_dom_integer_length_storage_is_bounded_by_the_final_strings() {
	mut texts := []string{cap: 2048}
	value := StyleValue(LengthStyleValue.create(Length.make_px(-2147483648.0)))
	before := platform.thread_arena_usage().used
	for _ in 0 .. 2048 { texts << serialize_dom_style_value(value) }
	$if prealloc {
		assert platform.thread_arena_usage().used - before <= 2048 * 32 + 4096
	}
	for text in texts {
		assert text == '-2147483648px'
	}
}
