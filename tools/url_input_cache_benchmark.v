// Component diagnostic, including result ownership and canonical serialization.
module main

import domurl
import encoding.hex
import os
import platform
import processmetrics

struct URLInputCase {
	input    string
	base     ?string
	expected string
}

fn measure_url_input_scene(name string, cases []URLInputCase, repetitions int, warm bool) {
	mut parser := domurl.URLInputParser{}
	defer { parser.clear() }
	if warm {
		for item in cases {
			record := parser.parse(item.input, item.base) or { panic('warm parse failed') }
			assert record.serialize(false) == item.expected
		}
	}
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. repetitions {
		// Only results belong to this iteration. Binding caches must outlive it.
		mut scratch := platform.begin_thread_scratch('URL input component results')
		for item in cases {
			record := parser.parse(item.input, item.base) or { panic('parse failed') }
			actual := record.serialize(false)
			assert actual == item.expected
			checksum += u64(actual.len)
		}
		scratch.finish()
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"parses":${cases.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	if os.args.len != 2 { panic('expected observed constructor input sequence TSV') }
	mut cases := []URLInputCase{}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		parts := line.split('\t')
		assert parts.len == 4 && parts[1] in ['0', '1']
		input := hex.decode(parts[2]) or { panic(err) }.bytestr()
		base := if parts[1] == '1' {
			?string(hex.decode(parts[3]) or { panic(err) }.bytestr())
		} else {
			none
		}
		expected := domurl.DOMURL.create_from_url(input, base) or { panic(err) }.href()
		cases << URLInputCase{ input: input, base: base, expected: expected }
	}
	assert cases.len > 0
	measure_url_input_scene('observed-constructors-cold', cases, 1, false)
	measure_url_input_scene('observed-constructors-warm', cases, 1, true)
	mut relatives := []URLInputCase{}
	for input in ['../next', '?q=x y', '#fragment', ''] {
		base := 'https://example.test/root/page?kept#before'
		relatives << URLInputCase{
			input:    input
			base:     base
			expected: domurl.DOMURL.create_from_url(input, base) or { panic(err) }.href()
		}
	}
	measure_url_input_scene('repeated-relative', relatives, 4096, true)
	mut unique := []URLInputCase{}
	for i in 0 .. 4096 {
		text := 'https://unique.test/path/${i}?query#fragment'
		unique << URLInputCase{ input: text, base: none, expected: text }
	}
	measure_url_input_scene('unique-inputs', unique, 1, true)
	oversized := 'https://oversize.test/' + 'x'.repeat(4096)
	measure_url_input_scene('oversized-input', [URLInputCase{
		input:    oversized
		base:     none
		expected: oversized
	}], 128, true)
}
