module url

// Retain the strict-split algorithm as an independent differential oracle.
fn split_last_label_ends_in_number(input string) bool {
	mut parts := input.split('.')
	if parts[parts.len - 1] == '' {
		if parts.len == 1 { return false }
		parts = parts[..parts.len - 1]
	}
	last := parts[parts.len - 1]
	mut digits := last.len > 0
	for byte in last.bytes() {
		if byte < `0` || byte > `9` { digits = false }
	}
	if digits { return true }
	if !last.starts_with('0x') && !last.starts_with('0X') { return false }
	for byte in last[2..].bytes() {
		if !is_ascii_hex_digit(byte) { return false }
	}
	return true
}

fn test_last_label_number_scan_matches_strict_split_for_every_short_ascii_input() {
	alphabet := '.01xXfG'.bytes()
	mut combinations := 1
	for length in 0 .. 7 {
		for value in 0 .. combinations {
			mut remaining := value
			mut bytes := []u8{len: length}
			for index in 0 .. length {
				bytes[index] = alphabet[remaining % alphabet.len]
				remaining /= alphabet.len
			}
			input := bytes.bytestr()
			assert ends_in_a_number_checker(input) == split_last_label_ends_in_number(input), input
		}
		combinations *= alphabet.len
	}
}

fn test_last_label_number_scan_preserves_byte_boundaries_and_single_trailing_dot() {
	for input in ['', '.', '..', '1.', '1..', '0x', '0X.', '.0x.', 'a.0x', 'a.0XfF.', 'a.0xg',
		'a.0129', 'a.0o10', 'a.+1', 'a.-1', 'a.１', 'я.12', 'я.12.', 'я.12..', 'a.12\x00',
		'a.0x\x00', 'a.\xff', 'a.\xff.1', 'a.0x\xff', 'a.0x1\n', 'a.1\n', 'a.٠١', 'a.0xé'] {
		assert ends_in_a_number_checker(input) == split_last_label_ends_in_number(input), input
	}
	for byte in 0 .. 256 {
		for prefix in ['', 'a.', '0x', 'a.0X'] {
			for suffix in ['', '.', '..', '.1', '.0xf'] {
				input := prefix + [u8(byte)].bytestr() + suffix
				assert ends_in_a_number_checker(input) == split_last_label_ends_in_number(input)
			}
		}
	}
}
