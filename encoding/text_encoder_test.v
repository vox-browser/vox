module encoding

fn test_encoding_is_utf_8() {
	encoder := TextEncoder.create()
	assert encoder.encoding() == 'utf-8'
}

fn test_encode_ascii() {
	encoder := TextEncoder.create()
	assert encoder.encode('hello') == [u8(104), 101, 108, 108, 111]
	assert encoder.encode('hello').bytestr() == 'hello'
	assert encoder.encode('') == []u8{}
}

fn test_encode_multibyte() {
	encoder := TextEncoder.create()
	// U+00E9 é -> 2 bytes, U+1D538 𝔸 (astral) -> 4 bytes.
	assert encoder.encode('é') == [u8(0xC3), 0xA9]
	assert encoder.encode('𝔸') == [u8(0xF0), 0x9D, 0x94, 0xB8]
	assert encoder.encode_to_byte_buffer('é𝔸') == 'é𝔸'.bytes()
}

fn test_encode_into_fits() {
	encoder := TextEncoder.create()
	mut dest := []u8{len: 5}
	result := encoder.encode_into('abc', mut dest)
	assert result.read == u64(3)
	assert result.written == u64(3)
	assert dest[..3].bytestr() == 'abc'
}

fn test_encode_into_result_is_the_raw_encoder_boundary() {
	encoder := TextEncoder.create()
	mut destination := []u8{len: 3}
	result := encoder.encode_into_result('Aé', mut destination)
	assert result == TextEncoderEncodeIntoResult{ read: 2, written: 3 }
	assert destination == 'Aé'.bytes()
}

fn test_encode_into_partial_ascii() {
	encoder := TextEncoder.create()
	// Only 2 bytes of room: 'a' and 'b' fit, 'c' does not, so the loop breaks.
	mut dest := []u8{len: 2}
	result := encoder.encode_into('abc', mut dest)
	assert result.read == u64(2)
	assert result.written == u64(2)
	assert dest.bytestr() == 'ab'
}

fn test_encode_into_whole_code_point_or_nothing() {
	encoder := TextEncoder.create()
	// A 2-byte code point does not fit in a 1-byte destination — nothing is written.
	mut small := []u8{len: 1}
	no_room := encoder.encode_into('é', mut small)
	assert no_room.read == u64(0)
	assert no_room.written == u64(0)
	// With exactly 2 bytes of room it fits: 1 code unit read, 2 bytes written.
	mut exact := []u8{len: 2}
	fits := encoder.encode_into('é', mut exact)
	assert fits.read == u64(1)
	assert fits.written == u64(2)
	assert exact == [u8(0xC3), 0xA9]
}

fn test_encode_into_astral_reads_two_code_units() {
	encoder := TextEncoder.create()
	// U+1D538 𝔸 is one code point but two UTF-16 code units and four UTF-8 bytes.
	mut dest := []u8{len: 4}
	result := encoder.encode_into('𝔸', mut dest)
	assert result.read == u64(2)
	assert result.written == u64(4)
	// One byte short: it does not fit, so nothing is read or written.
	mut short := []u8{len: 3}
	none_result := encoder.encode_into('𝔸', mut short)
	assert none_result.read == u64(0)
	assert none_result.written == u64(0)
}

fn test_encode_into_empty_source_and_zero_destination() {
	encoder := TextEncoder.create()
	// An empty source reads/writes nothing.
	mut dest := []u8{len: 4}
	empty := encoder.encode_into('', mut dest)
	assert empty.read == u64(0)
	assert empty.written == u64(0)
	// A zero-length destination (the detached-buffer case) reads/writes nothing.
	mut zero := []u8{}
	detached := encoder.encode_into('abc', mut zero)
	assert detached.read == u64(0)
	assert detached.written == u64(0)
}
