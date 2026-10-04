module main

import encoding
import libjs

fn main() {
	mut matches := true
	for be in [false, true] {
		label := if be { 'utf-16be' } else { 'utf-16le' }
		input := if be { [u8(0xd8), 0, 0] } else { [u8(0), 0xd8, 0] }
		mut stream := encoding.TextDecoderStream.create(label, encoding.TextDecoderOptions{})!
		stream.decode_and_enqueue_chunk(input)!
		result := stream.flush_and_enqueue()!
		owned := libjs.utf16_string_from_utf8_without_validation(result)
		units := owned.code_units()
		println('${label}: existing Stream units ${units}; native Source units [65533]')
		matches = matches && units == [u16(0xfffd)]
	}
	assert matches
}
