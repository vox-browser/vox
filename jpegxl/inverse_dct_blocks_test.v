module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_inverse_dct_subblocks_match_source_placement_and_lf_replacement() {
	mut count := 0
	mut words := 0
	mut kinds := map[int]int{}
	for line in $embed_file('testdata/inverse-dct-subblocks.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 4
		transform := hf_transform_from_id(f[0].int())!
		lf := [math.f32_from_bits(f[1].u32())]
		input_words := f[2].split(',').map(it.u32())
		input := input_words.map(math.f32_from_bits(it))
		actual := inverse_hf_transform(transform, lf, input)!
		assert actual.width == 8 && actual.height == 8 && actual.samples.len == 64
		mut data := []u8{len: 256}
		for k, value in actual.samples {
			binary.little_endian_put_u32_at(mut data, math.f32_bits(value), k * 4)
			assert math.f32_bits(input[k]) == input_words[k]
		}
		assert math.f32_bits(lf[0]) == f[1].u32()
		assert sha256.sum(data).hex() == f[3], 'DCT subblocks ${count}'
		kinds[int(transform)]++
		words += actual.samples.len
		count++
	}
	assert count == 1536
	assert words == 98304
	assert kinds.len == 3
	for _, cases in kinds { assert cases == 512 }
}
