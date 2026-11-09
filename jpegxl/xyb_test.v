module jpegxl

import crypto.sha256
import encoding.binary
import math

fn xyb_fixture_floats(text string) []f32 {
	return text.split(',').map(math.f32_from_bits(it.u32()))
}

fn test_xyb_matches_source_parameters_and_linear_rgb_samples() {
	mut count := 0
	for line in $embed_file('testdata/xyb.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 8
		m := xyb_fixture_floats(f[0])
		b := xyb_fixture_floats(f[1])
		opsin := OpsinInverseMatrix{ inverse_matrix: [m[0],m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8]]!, opsin_biases: [b[0],b[1],b[2]]! }
		intensity := math.f32_from_bits(f[2].u32())
		params := xyb_parameters(opsin, intensity)!
		mut actual := params.matrix[..].map(math.f32_bits(it))
		actual << params.bias_cbrt[..].map(math.f32_bits(it))
		actual << params.scaled_bias[..].map(math.f32_bits(it))
		actual << math.f32_bits(params.intensity_scale)
		assert actual == f[6].split(',').map(it.u32()), 'XYB parameters ${count}'
		input := [FloatPlane{ width: 16, height: 16, samples: xyb_fixture_floats(f[3]) },
			FloatPlane{ width: 16, height: 16, samples: xyb_fixture_floats(f[4]) },
			FloatPlane{ width: 16, height: 16, samples: xyb_fixture_floats(f[5]) }]!
		before := input[0].samples.clone()
		output := xyb_to_linear(input, opsin, intensity)!
		assert input[0].samples == before
		mut bytes := []u8{len: 3 * 256 * 4}
		for c in 0 .. 3 {
			assert output[c].width == 16 && output[c].height == 16
			for i, value in output[c].samples { binary.little_endian_put_u32_at(mut bytes, math.f32_bits(value), (c * 256 + i) * 4) }
		}
		assert sha256.sum(bytes).hex() == f[7], 'XYB output ${count}'
		count++
	}
	assert count == 128
}

fn test_xyb_checks_geometry_and_finite_parameters_and_preserves_empty_planes() {
	opsin := default_opsin()
	xyb_to_linear([FloatPlane{}, FloatPlane{}, FloatPlane{}]!, opsin, 255)!
	zero := FloatPlane{ width: 1, height: 1, samples: [f32(0)] }
	planes := [zero, zero, zero]!
	for target in [f32(0), -1, math.f32_from_bits(0x7f800000), math.f32_from_bits(0x7fc00000)] {
		if _ := xyb_to_linear(planes, opsin, target) { assert false }
	}
	if _ := xyb_to_linear([FloatPlane{}, zero, zero]!, opsin, 255) { assert false }
	if _ := xyb_to_linear([FloatPlane{ width: 1, height: 1 }, zero, zero]!, opsin, 255) { assert false }
	bad := FloatPlane{ width: 1, height: 1, samples: [math.f32_from_bits(0x7fc00000)] }
	if _ := xyb_to_linear([bad, zero, zero]!, opsin, 255) { assert false }
	if _ := xyb_to_linear(planes, OpsinInverseMatrix{ ...opsin, opsin_biases: [math.f32_from_bits(0x7f800000), f32(0), f32(0)]! }, 255) { assert false }
}
