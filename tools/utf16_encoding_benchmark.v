// Component diagnostic on retained URL strings, excluding input construction.
module main

import libjs
import os
import processmetrics

fn measure_utf16_scene(name string, texts []libjs.Utf16String, repetitions int) {
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. repetitions {
		for text in texts {
			encoded := text.str()
			checksum += u64(encoded.len)
			if encoded.len > 0 { checksum += u64(encoded[0]) + u64(encoded[encoded.len - 1]) }
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"encodes":${texts.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	if os.args.len != 2 { panic('expected a file containing retained URL strings') }
	mut urls := []libjs.Utf16String{}
	for text in os.read_lines(os.args[1]) or { panic(err) } {
		urls << libjs.utf16_string_from_code_units(libjs.utf16(text))
	}
	assert urls.len > 0
	measure_utf16_scene('archived-urls', urls, 128)
	measure_utf16_scene('long-ascii', [libjs.utf16_string_from_code_units([]u16{len: 16384, init: u16(32 + index % 95)})], 256)
	measure_utf16_scene('unicode-first', [libjs.utf16_string_from_code_units([]u16{len: 256, init: u16(0x4e00 + index)})], 4096)
	mut tail := []u16{len: 256, init: u16(32 + index % 95)}
	tail << [u16(0xd800), 0, 0xd83d, 0xde00, 0xdc00]
	measure_utf16_scene('surrogate-tail', [libjs.utf16_string_from_code_units(tail)], 4096)
	measure_utf16_scene('empty', [libjs.utf16_string_from_code_units([]u16{})], 65536)
}
