module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_inverse_dct_planes_match_source_axis_order_and_transpose() {
	mut count := 0
	mut words := 0
	mut geometries := map[string]int{}
	for line in $embed_file('testdata/inverse-dct-planes.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 4
		rows := f[0].int()
		columns := f[1].int()
		input_words := f[2].split(',').map(it.u32())
		input := input_words.map(math.f32_from_bits(it))
		actual := inverse_dct_plane(rows, columns, input)!
		assert actual.width == columns && actual.height == rows && actual.samples.len == input.len
		mut data := []u8{len: input.len * 4}
		for k, value in actual.samples {
			binary.little_endian_put_u32_at(mut data, math.f32_bits(value), k * 4)
			assert math.f32_bits(input[k]) == input_words[k]
		}
		assert sha256.sum(data).hex() == f[3], 'DCT plane ${count}'
		if rows == 8 && columns == 8 {
			assembled := inverse_hf_transform(.dct, [input[0]], input)!
			for k, value in assembled.samples { assert math.f32_bits(value) == math.f32_bits(actual.samples[k]) }
		}
		geometries['${rows}x${columns}']++
		words += input.len
		count++
	}
	assert count == 832
	assert words == 206080
	assert geometries.len == 13
	for _, cases in geometries { assert cases == 64 }
}

fn test_inverse_dct_planes_validate_geometry_and_samples() {
	for pair in [[0, 0]!, [1, 4]!, [2, 4]!, [4, 16]!, [8, 64]!, [-8, 8]!] {
		if _ := inverse_dct_plane(pair[0], pair[1], []f32{}) { assert false }
	}
	if _ := inverse_dct_plane(8, 8, []f32{len: 63}) { assert false }
	mut input := []f32{len: 64}
	input[63] = math.f32_from_bits(0x7fc00000)
	if _ := inverse_dct_plane(8, 8, input) { assert false }
}
