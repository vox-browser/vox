module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_dct_lf_injection_and_complete_small_transforms_match_source() {
	mut count := 0
	mut injected := map[int]bool{}
	mut transformed := map[int]bool{}
	for line in $embed_file('testdata/dct-lf.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		transform := hf_transform_from_id(f[1].int())!
		lf_words := f[2].split(',').map(it.u32())
		lf := lf_words.map(math.f32_from_bits(it))
		input_words := f[3].split(',').map(it.u32())
		input := input_words.map(math.f32_from_bits(it))
		actual := if f[0] == 'inject' {
			injected[int(transform)] = true
			inject_dct_lf(transform, lf, input)!
		} else {
			transformed[int(transform)] = true
			plane := inverse_hf_transform(transform, lf, input)!
			blocks := transform.covered_blocks()
			assert plane.width == blocks[0] * 8 && plane.height == blocks[1] * 8
			plane.samples
		}
		assert actual.len == input.len
		mut data := []u8{len: actual.len * 4}
		for k, value in actual {
			binary.little_endian_put_u32_at(mut data, math.f32_bits(value), k * 4)
			assert math.f32_bits(input[k]) == input_words[k]
		}
		for k, value in lf { assert math.f32_bits(value) == lf_words[k] }
		assert sha256.sum(data).hex() == f[4], 'LF DCT ${count} ${f[0]} ${transform}'
		count++
	}
	assert count == 576
	assert injected.len == 18
	assert transformed.len == 9
}

fn test_dct_lf_injection_rejects_invalid_geometry_and_samples() {
	for transform in [HfTransform.identity, .dct2x2, .dct4x4, .dct4x8, .afv0] {
		if _ := inject_dct_lf(transform, [f32(0)], []f32{len: 64}) { assert false }
	}
	if _ := inject_dct_lf(.dct16x16, [f32(0)], []f32{len: 256}) { assert false }
	if _ := inject_dct_lf(.dct16x16, []f32{len: 4}, []f32{len: 255}) { assert false }
	if _ := inject_dct_lf(.dct, [math.f32_from_bits(0x7f800000)], []f32{len: 64}) { assert false }
	mut samples := []f32{len: 64}
	samples[63] = math.f32_from_bits(0x7fc00000)
	if _ := inject_dct_lf(.dct, [f32(0)], samples) { assert false }
}
