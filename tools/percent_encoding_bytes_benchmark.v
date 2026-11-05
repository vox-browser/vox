// Component diagnostic. Setup/oracle creation is outside the counted interval.
module main

import platform
import processmetrics
import url

fn scalar_percent_encoding(input string, set url.PercentEncodeSet, plus bool) string {
	mut output := ''
	for r in input.runes() {
		if plus && r == ` ` {
			output += '+'
		} else if url.code_point_is_in_percent_encode_set(u32(r), set) {
			for b in r.bytes() { output += '%${b:02X}' }
		} else {
			output += r.str()
		}
	}
	return output
}

fn measure_percent_encoding(name string, inputs []string, set url.PercentEncodeSet, plus bool, repetitions int) {
	mut expected := []string{cap: inputs.len}
	for input in inputs { expected << scalar_percent_encoding(input, set, plus) }
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for group_start := 0; group_start < repetitions; group_start += 64 {
		mut scratch := platform.begin_thread_scratch('percent encoding component')
		group_end := if group_start + 64 < repetitions { group_start + 64 } else { repetitions }
		for _ in group_start .. group_end {
			for index, input in inputs {
				actual := url.percent_encode(input, set, plus)
				assert actual == expected[index]
				checksum += u64(actual.len)
			}
		}
		scratch.finish()
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"encodes":${inputs.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	measure_percent_encoding('single-ascii-path', ['a', '/', '.', '-', '_', '9', '%', '~'], .path, false, 8192)
	measure_percent_encoding('single-escaped-query', [' ', '#', '"', '<', '>', "'", '\t', '\u007f'], .special_query, false, 4096)
	measure_percent_encoding('unchanged-ascii', ['AZaz09-._'.repeat(64)], .userinfo, false, 128)
	measure_percent_encoding('mixed-query', ['key=value with spaces&next=%7Bvalue%7D'], .special_query, false, 8192)
	measure_percent_encoding('space-as-plus', ['words with + & % and spaces'], .application_x_www_form_urlencoded, true, 8192)
	measure_percent_encoding('unicode', ['é漢😀'.repeat(16)], .component, false, 512)
	measure_percent_encoding('malformed-utf8', [[u8(0xe2), 0x28, 0xa1, 0xff].bytestr()], .path, false, 4096)
}
