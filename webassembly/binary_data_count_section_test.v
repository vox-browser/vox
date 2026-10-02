module webassembly

import webidl

fn data_count_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 12, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_data_count_parser_retains_count_and_source_eof_behavior() {
	for index, payload in [[u8(0)], [u8(0x80), 1], [u8(0xff), 0xff, 0xff, 0xff, 0x0f]] {
		mut decoder := Decoder{ bytes: payload }
		section := parse_data_count_section(mut decoder)!
		assert section.count? == [u32(0), 128, 0xffffffff][index]
	}
	// Module serialization uses a count that agrees with its actual segments.
	compiled := compile_module(data_count_section_binary([u8(0)]))!
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.data_count == compiled.data_count
	// Pinned DataCountSection::parse returns an absent count on any read error
	// when its constrained stream is at EOF, including these truncated inputs.
	for payload in [[]u8{}, [u8(0x80)], [u8(0x80), 0x80]] {
		assert compile_module(data_count_section_binary(payload))!.data_count == none
	}
}

fn test_data_count_parser_rejects_failed_reads_before_eof_and_trailing_bytes() {
	for payload in [[u8(0), 0], [u8(0x80), 1, 0], [u8(0xff), 0xff, 0xff, 0xff, 0x10, 0],
		[u8(0x80), 0x80, 0x80, 0x80, 0x80, 0]] {
		assert !validate(webidl.BufferSource.array_buffer(data_count_section_binary(payload)))
	}
}
