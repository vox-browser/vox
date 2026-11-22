module fastsha256

import crypto.sha256

fn test_digests_match_the_portable_implementation() {
	mut inputs := ['', 'abc', 'The quick brown fox jumps over the lazy dog']
	inputs << 'x'.repeat(55)
	inputs << 'y'.repeat(56)
	inputs << 'z'.repeat(64)
	inputs << 'w'.repeat(1000003)
	for input in inputs {
		assert hexhash(input) == sha256.hexhash(input)
		assert sum(input.bytes()) == sha256.sum(input.bytes())
	}
	assert hexhash('abc') == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
}

fn test_empty_and_slice_inputs() {
	data := []u8{len: 4096, init: u8(index * 7)}
	assert sum(data[1..4095]) == sha256.sum(data[1..4095])
	assert sum([]u8{}) == sha256.sum([]u8{})
}
