module webassembly

fn test_binary_byte_vectors_own_exact_contents_and_consume_the_source_prefix() {
	mut input := [u8(3), 0, 0xff, 0x80, 42]
	mut decoder := Decoder{ bytes: input }
	vector := decoder.byte_vector()!
	assert vector == [u8(0), 0xff, 0x80] && decoder.offset == 4
	input[1] = 99
	assert vector[0] == 0
	assert decoder.byte()! == 42
	mut empty := Decoder{ bytes: [u8(0)] }
	assert empty.byte_vector()!.len == 0
}

fn test_binary_byte_vectors_keep_the_source_size_limit_and_utf8_name_validation() {
	for bytes in [[u8(2), 1], [u8(0x80)]] {
		mut decoder := Decoder{ bytes: bytes }
		if _ := decoder.byte_vector() { assert false } else { assert err.msg().len > 0 }
	}
	mut oversized := Decoder{ bytes: [u8(0x81), 0x80, 0x80, 0xfa, 1] }
	if _ := oversized.byte_vector() { assert false } else { assert err.msg().contains('allocation limit') }
	mut invalid_name := Decoder{ bytes: [u8(2), 0xc0, 0xaf] }
	if _ := invalid_name.name() { assert false } else { assert err.msg().contains('UTF-8') }
}
