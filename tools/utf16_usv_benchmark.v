// Component diagnostic with full output references outside input construction.
module main

import libjs
import os
import processmetrics

fn measure_usv_scene(name string, texts []libjs.Utf16String, repetitions int) {
	expected := texts.map(it.to_well_formed().str())
	for i, text in texts { assert text.to_well_formed_utf8() == expected[i] }
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. repetitions {
		for i, text in texts {
			encoded := text.to_well_formed_utf8()
			assert encoded == expected[i]
			checksum += u64(encoded.len)
			if encoded.len > 0 { checksum += u64(encoded[0]) + u64(encoded[encoded.len - 1]) }
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"encodes":${texts.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	if os.args.len != 2 { panic('expected a file containing retained URL strings') }
	urls := (os.read_lines(os.args[1]) or { panic(err) }).map(libjs.utf16_string(it))
	assert urls.len == 311
	measure_usv_scene('archived-urls', urls, 128)
	measure_usv_scene('long-ascii', [libjs.utf16_string_from_code_units([]u16{len: 16384, init: u16(32 + index % 95)})], 256)
	measure_usv_scene('unicode-first', [libjs.utf16_string_from_code_units([]u16{len: 256, init: u16(0x4e00 + index)})], 4096)
	mut tail := []u16{len: 256, init: u16(32 + index % 95)}
	tail << [u16(0xd800), 0, 0xd83d, 0xde00, 0xdc00]
	measure_usv_scene('surrogate-tail', [libjs.utf16_string_from_code_units(tail)], 4096)
	measure_usv_scene('empty', [libjs.utf16_string_from_code_units([]u16{})], 65536)
	measure_usv_scene('unchecked-bytes', [libjs.utf16_string_from_ascii_without_validation([]u8{len: 256, init: u8(index)})], 4096)
}
