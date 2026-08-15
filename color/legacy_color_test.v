module color

fn legacy_rgb(input string) []u8 {
	c := parse_legacy_color_value(input) or { panic('failed to parse ${input}') }
	return [c.red, c.green, c.blue]
}

fn test_named_colors() {
	assert legacy_rgb('red') == [u8(255), 0, 0]
	assert legacy_rgb('BLUE') == [u8(0), 0, 255]
	assert legacy_rgb('  lime  ') == [u8(0), 255, 0] // surrounding whitespace is stripped
}

fn test_short_hex_form() {
	// #RGB doubles each digit.
	assert legacy_rgb('#f00') == [u8(255), 0, 0]
	assert legacy_rgb('#abc') == [u8(0xaa), 0xbb, 0xcc]
	assert legacy_rgb('#0f0') == [u8(0), 255, 0]
}

fn test_six_digit_hex() {
	assert legacy_rgb('#ff8800') == [u8(255), 0x88, 0]
	assert legacy_rgb('#123456') == [u8(0x12), 0x34, 0x56]
	// A missing leading "#" is fine in the fallback path.
	assert legacy_rgb('00ff00') == [u8(0), 255, 0]
}

fn test_failure_cases() {
	assert parse_legacy_color_value('') == none
	assert parse_legacy_color_value('transparent') == none
	assert parse_legacy_color_value('TRANSPARENT') == none
}

fn test_legacy_fallback_quirks() {
	// The famous "chucknorris" parses to #C00000 via the historical fallback.
	assert legacy_rgb('chucknorris') == [u8(0xc0), 0, 0]
	// Non-hex characters become 0.
	assert legacy_rgb('#gggggg') == [u8(0), 0, 0]
}
