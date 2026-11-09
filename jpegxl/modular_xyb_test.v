module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_modular_xyb_matches_native_both_integer_widths_and_f32_sum_order() {
	mut count := 0
	mut words := 0
	for line in $embed_file('testdata/modular-xyb.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 6
		q := f[1].split(',').map(math.f32_from_bits(it.u32()))
		mut input := []ModularChannel{cap: 3}
		for c in 0 .. 3 {
			samples := f[c + 2].split(',').map(i32(it.i64()))
			input << ModularChannel{ width: 4, height: samples.len / 4, samples: samples }
		}
		before := input[0].samples.clone()
		output := modular_xyb_planes(input, LfQuantFactors{ quant_factors: [q[0],q[1],q[2]]! },
			if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 })!
		assert input[0].samples == before
		mut data := []u8{len: 3 * input[0].samples.len * 4}
		for c in 0 .. 3 {
			assert output[c].width == 4 && output[c].height == input[c].height
			for i, value in output[c].samples { binary.little_endian_put_u32_at(mut data, math.f32_bits(value), (c * input[c].samples.len + i) * 4) }
		}
		assert sha256.sum(data).hex() == f[5], 'Modular XYB ${count}'
		words += 3 * input[0].samples.len
		count++
	}
	assert count == 512 && words == 130560
}

fn test_modular_xyb_adds_rounded_floats_and_normalizes_i16_before_scaling() {
	input := [ModularChannel{ width: 1, height: 1, samples: [i32(16777217)] },
		ModularChannel{ width: 1, height: 1, samples: [i32(3)] },
		ModularChannel{ width: 1, height: 1, samples: [i32(-16777216)] }]
	q := LfQuantFactors{ quant_factors: [f32(2),3,5]! }
	output := modular_xyb_planes(input, q, .signed32)!
	assert output[0].samples == [f32(6)]
	assert output[2].samples == [f32(0)]
	wrapped := [ModularChannel{ width: 1, height: 1, samples: [i32(65535)] },
		ModularChannel{ width: 1, height: 1, samples: [i32(65536)] },
		ModularChannel{ width: 1, height: 1, samples: [i32(65537)] }]
	actual := modular_xyb_planes(wrapped, q, .signed16)!
	assert actual[0].samples == [f32(0)] && actual[1].samples == [f32(-3)] && actual[2].samples == [f32(0)]
}

fn test_modular_xyb_validates_shapes_scales_and_empty_planes() {
	q := LfQuantFactors{ quant_factors: [f32(1),1,1]! }
	input := []ModularChannel{len: 3}
	assert modular_xyb_planes(input, q, .signed32)![0].samples.len == 0
	if _ := modular_xyb_planes(input[..2], q, .signed32) { assert false }
	for invalid in [f32(0),-1,math.f32_from_bits(0x7f800000),math.f32_from_bits(0x7fc00000)] {
		if _ := modular_xyb_planes(input, LfQuantFactors{ quant_factors: [invalid,f32(1),f32(1)]! }, .signed32) { assert false }
	}
	bad := [ModularChannel{ width: 1, height: 1, samples: [i32(0)] }, ModularChannel{}, ModularChannel{}]
	if _ := modular_xyb_planes(bad, q, .signed32) { assert false }
}
