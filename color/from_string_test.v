module color

fn rgba(input string) []u8 {
	c := from_string(input) or { panic('failed to parse ${input}') }
	return [c.red, c.green, c.blue, c.alpha]
}

fn test_hex_forms() {
	// #RGB and #RGBA double each digit; #RRGGBB and #RRGGBBAA take pairs.
	assert rgba('#f00') == [u8(255), 0, 0, 255]
	assert rgba('#f008') == [u8(255), 0, 0, 136] // 8 * 17
	assert rgba('#ff0000') == [u8(255), 0, 0, 255]
	assert rgba('#00ff0080') == [u8(0), 255, 0, 128]
}

fn test_hex_invalid() {
	assert from_string('#gg0000') == none // invalid hex digit
	assert from_string('#12') == none // wrong length
	assert from_string('#1234567') == none // length 8 is invalid
}

fn test_rgb_function() {
	assert rgba('rgb(255, 128, 0)') == [u8(255), 128, 0, 255]
	assert rgba('RGB(1,2,3)') == [u8(1), 2, 3, 255] // case-insensitive
	// Out-of-range components are clamped to 0..255.
	assert rgba('rgb(300, -5, 0)') == [u8(255), 0, 0, 255]
	// The wrong number of components fails.
	assert from_string('rgb(1, 2)') == none
	assert from_string('rgb(1, 2, x)') == none
}

fn test_rgba_function() {
	assert rgba('rgba(0, 0, 255, 1)') == [u8(0), 0, 255, 255]
	assert rgba('rgba(0, 0, 0, 0.5)') == [u8(0), 0, 0, 127] // 0.5 * 255 truncated
	assert rgba('rgba(0, 0, 0, 0)') == [u8(0), 0, 0, 0]
	// An alpha above 1 (a > 255) fails.
	assert from_string('rgba(0, 0, 0, 2)') == none
	assert from_string('rgba(0, 0, 0)') == none // needs four components
}

fn test_transparent_and_named() {
	assert rgba('transparent') == [u8(0), 0, 0, 0]
	assert rgba('TRANSPARENT') == [u8(0), 0, 0, 0]
	assert rgba('red') == [u8(255), 0, 0, 255]
	assert rgba('CornflowerBlue') == [u8(0x64), 0x95, 0xed, 255]
}

fn test_invalid_strings() {
	assert from_string('') == none
	assert from_string('notacolor') == none
}
