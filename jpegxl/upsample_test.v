module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_upsampling_matches_native_2x_4x_8x_complete_planes() {
	mut counts := [3]int{}
	mut words := 0
	for line in $embed_file('testdata/upsample-planes.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 8
		factor := f[0].int()
		weights := f[5].split(',').map(math.f32_from_bits(it.u32()))
		input := FloatPlane{ width: f[1].int(), height: f[2].int(), samples: f[6].split(',').map(math.f32_from_bits(it.u32())) }
		before := input.samples.map(math.f32_bits(it))
		output := upsample_plane(input, factor, weights, f[3].int(), f[4].int())!
		assert output.width == f[3].int() && output.height == f[4].int()
		assert input.samples.map(math.f32_bits(it)) == before
		mut bytes := []u8{len: output.samples.len*4}
		for i, value in output.samples { binary.little_endian_put_u32_at(mut bytes, math.f32_bits(value), i*4) }
		assert sha256.sum(bytes).hex() == f[7], 'Upsample ${factor}x case ${counts}'
		counts[ceil_log2(factor)-1]++
		words += output.samples.len
	}
	assert counts == [128,128,128]!
	assert words == 246656
}

fn test_upsampling_rejects_shapes_weights_factors_and_excessive_allocations() {
	p := FloatPlane{ width: 1, height: 1, samples: [f32(0)] }
	weights := default_kernel_2[..]
	for factor in [0,1,3,16] { if _ := upsample_plane(p, factor, weights, 2, 2) { assert false } }
	for shape in [[0,2]!,[2,0]!,[3,2]!,[2,3]!,[65536,65536]!] {
		if _ := upsample_plane(p, 2, weights, shape[0], shape[1]) { assert false }
	}
	if _ := upsample_plane(p, 2, weights[..14], 2, 2) { assert false }
	mut invalid := weights.clone()
	invalid[0] = math.f32_from_bits(0x7f800000)
	if _ := upsample_plane(p, 2, invalid, 2, 2) { assert false }
	if _ := upsample_plane(FloatPlane{}, 2, weights, 2, 2) { assert false }
}
