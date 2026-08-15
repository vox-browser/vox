module color

fn rgb(name string) []u8 {
	c := from_named_css_color_string(name) or { panic('unknown color ${name}') }
	return [c.red, c.green, c.blue]
}

fn test_basic_named_colors() {
	assert rgb('black') == [u8(0), 0, 0]
	assert rgb('white') == [u8(255), 255, 255]
	assert rgb('red') == [u8(255), 0, 0]
	assert rgb('lime') == [u8(0), 255, 0]
	assert rgb('blue') == [u8(0), 0, 255]
}

fn test_alpha_is_opaque() {
	c := from_named_css_color_string('red') or { panic('') }
	assert c.alpha == u8(255)
}

fn test_extended_named_colors() {
	assert rgb('rebeccapurple') == [u8(0x66), 0x33, 0x99]
	assert rgb('cornflowerblue') == [u8(0x64), 0x95, 0xed]
	assert rgb('rosybrown') == [u8(0xbc), 0x8f, 0x8f]
	assert rgb('lightgoldenrodyellow') == [u8(0xfa), 0xfa, 0xd2]
	// gray/grey aliases resolve to the same color.
	assert rgb('gray') == rgb('grey')
	assert rgb('darkgray') == rgb('darkgrey')
}

fn test_case_insensitive() {
	assert rgb('RED') == [u8(255), 0, 0]
	assert rgb('CornflowerBlue') == [u8(0x64), 0x95, 0xed]
	assert rgb('REBECCAPURPLE') == [u8(0x66), 0x33, 0x99]
}

fn test_unknown_and_transparent_are_none() {
	assert from_named_css_color_string('notacolor') == none
	assert from_named_css_color_string('') == none
	// "transparent" is not part of the named-color table.
	assert from_named_css_color_string('transparent') == none
	// A hex string is not a named color.
	assert from_named_css_color_string('#ff0000') == none
}
