module jpegxl

import math

fn test_inverse_dct_vectors_match_original_source_kernels() {
	mut count := 0
	mut words := 0
	mut sizes := map[int]int{}
	for line in $embed_file('testdata/inverse-dct-vectors.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 2
		input_words := f[0].split(',').map(it.u32())
		input := input_words.map(math.f32_from_bits(it))
		expected := f[1].split(',').map(it.u32())
		actual := inverse_dct_vector(input)!
		assert actual.len == expected.len
		for k, value in actual {
			assert math.f32_bits(value) == expected[k], 'DCT vector ${count}, sample ${k}'
			assert math.f32_bits(input[k]) == input_words[k]
		}
		sizes[input.len]++
		words += actual.len
		count++
	}
	assert count == 2560
	assert words == 31744
	assert sizes.len == 5
	for _, cases in sizes { assert cases == 512 }
}

fn test_inverse_dct_vectors_reject_invalid_sizes_and_nonfinite_inputs() {
	for n in [0, 1, 3, 6, 31, 33, 64] {
		if _ := inverse_dct_vector([]f32{len: n}) { assert false }
	}
	for bits in [u32(0x7f800000), 0xff800000, 0x7fc00000] {
		mut input := []f32{len: 32}
		input[31] = math.f32_from_bits(bits)
		if _ := inverse_dct_vector(input) { assert false }
	}
}
