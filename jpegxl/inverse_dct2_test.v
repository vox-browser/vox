module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_inverse_dct2_matches_complete_source_blocks() {
	mut count := 0
	for line in $embed_file('testdata/inverse-dct2.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		lf := [math.f32_from_bits(f[0].u32())]
		coefficients := f[1].split(',').map(math.f32_from_bits(it.u32()))
		before := coefficients.clone()
		actual := inverse_hf_transform(.dct2x2, lf, coefficients)!
		assert actual.width == 8 && actual.height == 8 && actual.samples.len == 64
		assert coefficients == before && math.f32_bits(lf[0]) == f[0].u32()
		mut data := []u8{len: 256}
		for k, value in actual.samples { binary.little_endian_put_u32_at(mut data, math.f32_bits(value), k * 4) }
		assert sha256.sum(data).hex() == f[2], 'DCT2X2 block ${count}'
		count++
	}
	assert count == 512
}
