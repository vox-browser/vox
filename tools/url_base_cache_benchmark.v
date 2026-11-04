// Component comparison with complete canonical output references.
module main

import domurl
import os
import processmetrics
import url

fn measure_base_scene(name string, inputs []string, bases []string, expected []string, repetitions int) {
	assert inputs.len == bases.len && inputs.len == expected.len && inputs.len > 0
	mut parser := domurl.URLBaseParser{}
	defer { parser.clear() }
	for i, input in inputs {
		record := parser.parse(input, bases[i]) or { panic('URL warm parse failed') }
		assert record.serialize(false) == expected[i]
	}
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. repetitions {
		for i, input in inputs {
			record := parser.parse(input, bases[i]) or { panic('URL parse failed') }
			serialized := record.serialize(false)
			assert serialized == expected[i]
			checksum += u64(serialized.len)
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"parses":${inputs.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	if os.args.len != 2 { panic('expected retained canonical resource URLs') }
	urls := os.read_lines(os.args[1]) or { panic(err) }
	assert urls.len == 311
	measure_base_scene('archived-absolute', urls,
		[]string{len: urls.len, init: 'https://chatgpt.com/'}, urls, 32)
	measure_base_scene('relative-inputs', ['../next', '?q=x y', '#fragment', ''],
		[]string{len: 4, init: 'https://example.test/root/page?kept#before'},
		['https://example.test/next', 'https://example.test/root/page?q=x%20y',
		 'https://example.test/root/page?kept#fragment', 'https://example.test/root/page?kept'], 4096)
	mut fragments := []string{cap: urls.len}
	for text in urls {
		record := url.parse(text) or { panic('base URL') }
		fragments << record.with_fragment('fragment').serialize(false)
	}
	measure_base_scene('rotating-bases', []string{len: urls.len, init: '#fragment'}, urls, fragments, 32)
	oversized := 'https://oversize.test/' + 'x'.repeat(4096)
	measure_base_scene('oversized-base', ['#fragment'], [oversized], [oversized + '#fragment'], 128)
}
