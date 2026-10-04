module encoding

fn test_source_replacement_raw_decoder_emitted_and_capacity_state() {
	mut decoder := ReplacementDecoder{}
	mut room := []u8{len: 3}
	result0, read0, written0 := decoder.decode_to_utf8_raw([], [], false)
	assert result0.status == .input_empty && read0 == 0 && written0 == 0
	assert !decoder.emitted
	result1, read1, written1 := decoder.decode_to_utf8_raw('AB'.bytes(), room[..2], false)
	assert result1.status == .output_full && read1 == 0 && written1 == 0
	assert !decoder.emitted
	result2, read2, written2 := decoder.decode_to_utf8_raw('AB'.bytes(), room, false)
	assert result2.status == .malformed && result2.malformed_length == 1
	assert result2.bytes_after == 0 && read2 == 1 && written2 == 0
	assert decoder.emitted && room == [u8(0), 0, 0]
	result3, read3, written3 := decoder.decode_to_utf8_raw('BC'.bytes(), [], true)
	assert result3.status == .input_empty && read3 == 2 && written3 == 0
}

fn test_source_replacement_wrapper_emits_once_and_consumes_later_chunks() {
	mut decoder := ReplacementDecoder{}
	mut short := []u8{len: 2}
	status0, read0, written0, errors0 := decoder.decode_to_utf8('A'.bytes(), mut short,
		false)
	assert status0 == .output_full && read0 == 0 && written0 == 0 && !errors0
	mut room := []u8{len: 3}
	status1, read1, written1, errors1 := decoder.decode_to_utf8('AB'.bytes(), mut room,
		false)
	assert status1 == .input_empty && read1 == 2 && written1 == 3 && errors1
	assert room == [u8(0xef), 0xbf, 0xbd]
	mut empty := []u8{}
	status2, read2, written2, errors2 := decoder.decode_to_utf8('CDEF'.bytes(), mut empty,
		true)
	assert status2 == .input_empty && read2 == 4 && written2 == 0 && !errors2
}

fn test_source_internal_replacement_fallback_uses_decoder_and_bom_override() {
	for label in ['replacement', 'csiso2022kr', 'hz-gb-2312', 'iso-2022-cn', 'iso-2022-cn-ext',
		'iso-2022-kr', ' \tISO-2022-KR\r\n'] {
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label,
			[])! == ''
		for bytes in ['A'.bytes(), 'AB'.bytes(), [u8(0), 0xff, 0x61], [u8(0xef), 0xbb], [u8(0xff)]] {
			assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label,
				bytes)! == '\ufffd'
		}
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label,
			[u8(0xef), 0xbb, 0xbf, 0x41])! == 'A'
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label,
			[u8(0xff), 0xfe, 0x41, 0])! == 'A'
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label,
			[u8(0xfe), 0xff, 0, 0x41])! == 'A'
		TextDecoder.construct(label, TextDecoderOptions{}) or {
			assert err.msg().starts_with('RangeError:')
			continue
		}
		assert false, 'Source public TextDecoder must still reject replacement'
	}
}
