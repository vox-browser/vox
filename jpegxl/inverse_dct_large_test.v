module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_large_inverse_dct_vectors_planes_and_complete_transforms_match_source() {
	mut count := 0
	mut words := 0
	mut modes := map[string]int{}
	mut transformed := map[int]bool{}
	for line in $embed_file('testdata/inverse-dct-large.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		tag := f[1].int()
		input_words := f[3].split(',').map(it.u32())
		input := input_words.map(math.f32_from_bits(it))
		actual := if f[0] == 'vector' {
			assert input.len == tag
			inverse_dct_vector(input)!
		} else {
			transform := hf_transform_from_id(tag)!
			blocks := transform.covered_blocks()
			plane := if f[0] == 'plane' {
				inverse_dct_plane(blocks[1] * 8, blocks[0] * 8, input)!
			} else {
				transformed[tag] = true
				lf := f[2].split(',').map(math.f32_from_bits(it.u32()))
				inverse_hf_transform(transform, lf, input)!
			}
			assert plane.width == blocks[0] * 8 && plane.height == blocks[1] * 8
			plane.samples
		}
		assert actual.len == input.len
		mut data := []u8{len: actual.len * 4}
		for k, value in actual {
			binary.little_endian_put_u32_at(mut data, math.f32_bits(value), k * 4)
			assert math.f32_bits(input[k]) == input_words[k]
		}
		assert sha256.sum(data).hex() == f[4], 'Large DCT ${count} ${f[0]} ${tag}'
		modes[f[0]]++
		words += actual.len
		count++
	}
	assert count == 438
	assert modes['vector'] == 384 && modes['plane'] == 27 && modes['full'] == 27
	assert transformed.len == 9
	assert words == 1089536
}
