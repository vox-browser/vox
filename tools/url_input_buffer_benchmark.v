// Component diagnostic: parse and serialize retained canonical resource URLs.
module main

import os
import processmetrics
import url

fn measure_url_inputs(name string, inputs []string, expected []string, repetitions int,
	base ?&url.URL) {
	assert inputs.len == expected.len && inputs.len > 0
	// Warm and audit every input before reading the counter.
	for i, input in inputs {
		actual := if seed := base { seed.with_path(input) }
			else { url.parse(input) or { panic('URL parse failed') } }
		assert actual.serialize(false) == expected[i]
	}
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. repetitions {
		for i, input in inputs {
			actual := if seed := base { seed.with_path(input) }
				else { url.parse(input) or { panic('URL parse failed') } }
			serialized := actual.serialize(false)
			assert serialized == expected[i]
			checksum += u64(serialized.len)
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"parses":${inputs.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	if os.args.len != 2 { panic('expected a file containing canonical retained URLs') }
	inputs := os.read_lines(os.args[1]) or { panic(err) }
	measure_url_inputs('archived-urls', inputs, inputs, 32, none)
	with_controls := inputs.map('\x01\t ' + it + '\r\n\x1f ')
	measure_url_inputs('edge-controls', with_controls, inputs, 32, none)
	seed := url.parse('https://example.test/old?kept#fragment') or { panic('base') }
	measure_url_inputs('path-overrides', ['/path', ' a\t?b#c ', '/a/../b', '\t\n\r'],
		['https://example.test/path?kept#fragment',
		 'https://example.test/%20a%3Fb%23c%20?kept#fragment',
		 'https://example.test/b?kept#fragment',
		 'https://example.test/?kept#fragment'], 4096, &seed)
}
