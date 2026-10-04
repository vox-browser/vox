module encoding

fn test_source_bom_override_selects_utf8_utf16_and_keeps_fallback_replacement_behavior() {
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', 'héllo'.bytes())! == 'héllo'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFF),
		0x61,
	])! == '\ufffda'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-16LE', [
		u8(0x61),
		0,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-16LE', [
		u8(0xEF),
		0xBB,
		0xBF,
		0x61,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFF),
		0xFE,
		0x61,
		0,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFE),
		0xFF,
		0,
		0x61,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFE),
		0xFF,
		0xD8,
		0,
		0x61,
	])! == '\ufffd\ufffd'
}

fn test_pinned_source_removes_two_same_encoding_boms_but_keeps_a_third_and_opposing_bom() {
	for bom in [[u8(0xEF), 0xBB, 0xBF], [u8(0xFF), 0xFE], [u8(0xFE), 0xFF]] {
		mut two := bom.clone()
		two << bom
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', two)! == ''
		mut three := two.clone()
		three << bom
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', three)! == '\ufeff'
	}
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFF),
		0xFE,
		0xFE,
		0xFF,
	])! == '\ufffe'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFE),
		0xFF,
		0xFF,
		0xFE,
	])! == '\ufffe'
}
