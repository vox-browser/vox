module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_inverse_identity_matches_complete_source_blocks() {
	mut count := 0
	for line in $embed_file('testdata/inverse-identity.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		lf := [math.f32_from_bits(f[0].u32())]
		coefficients := f[1].split(',').map(math.f32_from_bits(it.u32()))
		before := coefficients.clone()
		actual := inverse_hf_transform(.identity, lf, coefficients)!
		assert actual.width == 8 && actual.height == 8 && actual.samples.len == 64
		assert coefficients == before && math.f32_bits(lf[0]) == f[0].u32()
		mut data := []u8{len: 256}
		for k, value in actual.samples { binary.little_endian_put_u32_at(mut data, math.f32_bits(value), k * 4) }
		assert sha256.sum(data).hex() == f[2], 'Identity block ${count}'
		count++
	}
	assert count == 512
}

fn test_inverse_transform_validates_input_buffers_and_rejects_unsupported_modes() {
	for transform in [HfTransform.identity, .dct] {
		if _ := inverse_hf_transform(transform, []f32{}, []f32{len: 64}) { assert false }
		if _ := inverse_hf_transform(transform, [f32(0)], []f32{len: 63}) { assert false }
	}
	for bits in [u32(0x7f800000), 0x7fc00000, 0xff800000] {
		if _ := inverse_hf_transform(.identity, [math.f32_from_bits(bits)], []f32{len: 64}) { assert false }
		mut samples := []f32{len: 64}
		samples[63] = math.f32_from_bits(bits)
		if _ := inverse_hf_transform(.identity, [f32(0)], samples) { assert false }
	}
	if _ := inverse_hf_transform(.dct, [f32(0)], []f32{len: 64}) { assert false }
}
