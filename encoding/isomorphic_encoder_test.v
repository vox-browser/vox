module encoding

import libjs

fn test_source_isomorphic_encode_preserves_latin1_values_and_empty_input() {
	assert isomorphic_encode_utf16(libjs.utf16_string_from_code_units([u16(0), 0x41, 0x80, 0xe9, 0xff])) == [u8(0), 0x41, 0x80, 0xe9, 0xff]
	assert isomorphic_encode_utf8('Aéÿ') == [u8(0x41), 0xe9, 0xff]
	assert isomorphic_encode_utf8('') == []u8{}
}

fn test_source_isomorphic_encode_iterates_pairs_and_lone_surrogates_before_truncation() {
	input := libjs.utf16_string_from_code_units([u16(0xd800), 0x41, 0xdcff, 0xff, 0xd83d, 0xde80, 0xdbff, 0xdfff])
	assert isomorphic_encode_utf16(input) == [u8(0), 0x41, 0xff, 0xff, 0x80, 0xff]
	assert isomorphic_encode_utf8(input.str()) == [u8(0), 0x41, 0xff, 0xff, 0x80, 0xff]
}

fn test_source_isomorphic_string_view_boundary_uses_unvalidated_utf8_iteration() {
	// AK's iterator retains overlong slash and a lonely surrogate, while an
	// invalid lead byte produces U+FFFD. Source's byte cast follows decoding.
	assert isomorphic_encode_utf8([u8(0xc0), 0xaf, 0xed, 0xa0, 0x80, 0xff].bytestr()) == [u8(0x2f), 0, 0xfd]
}
