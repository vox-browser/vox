module css

fn test_short_math_display_is_inline_and_uses_short_serialization() {
	display := Display.from_short(.math)

	assert display.is_inline_outside()
	assert display.is_math_inside()
	assert display.to_string() == 'math'
	assert Display.from_outside_inside(.block, .math).to_string() == 'block math'
}

fn test_parsed_math_display_serializes_as_math() {
	parsed := parse_css_value_logic(.display, 'math') or { panic('display: math did not parse') }
	assert parsed is DisplayStyleValue
	assert parsed.serialize(.normal) == 'math'
}
