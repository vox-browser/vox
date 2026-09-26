module css

import strconv

// https://html.spec.whatwg.org/multipage/rendering.html#rules-for-parsing-a-legacy-font-size
// HTMLFontElement::parse_legacy_font_size(). HTML's presentational hints and
// Editing's font size conversions both resolve legacy sizes to an
// <absolute-size> keyword, so the algorithm lives below both packages.
pub fn parse_legacy_font_size(input string) ?string {
	mut position := 0
	for position < input.len && input[position] in [` `, `\t`, `\n`, `\f`, `\r`] {
		position++
	}
	if position == input.len {
		return none
	}
	mut mode := 0
	if input[position] == `+` {
		mode = 1
		position++
	} else if input[position] == `-` {
		mode = -1
		position++
	}
	start := position
	for position < input.len && input[position] >= `0` && input[position] <= `9` {
		position++
	}
	if position == start {
		return none
	}
	mut value := strconv.atoi(input[start..position]) or { return none }
	if mode == 1 {
		value += 3
	} else if mode == -1 {
		value = 3 - value
	}
	value = if value < 1 {
		1
	} else if value > 7 {
		7
	} else {
		value
	}
	return ['x-small', 'small', 'medium', 'large', 'x-large', 'xx-large', 'xxx-large'][value - 1]
}
