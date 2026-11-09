module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_srgb_transfer_matches_source_simd_in_both_directions() {
	mut count := 0
	for line in $embed_file('testdata/srgb-transfer.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		input := FloatPlane{ width: 256, height: 1, samples: f[1].split(',').map(math.f32_from_bits(it.u32())) }
		direction := if f[0] == 'inverse' { SrgbTransferDirection.to_linear } else { SrgbTransferDirection.from_linear }
		before := input.samples.clone()
		output := srgb_transfer(input, direction)!
		assert input.samples == before
		assert output.width == 256 && output.height == 1
		mut bytes := []u8{len: output.samples.len * 4}
		for i, value in output.samples { binary.little_endian_put_u32_at(mut bytes, math.f32_bits(value), i * 4) }
		assert sha256.sum(bytes).hex() == f[2], 'sRGB transfer ${count}'
		assert math.f32_bits(output.samples[0]) == 0
		assert math.f32_bits(output.samples[1]) == 0x80000000
		count++
	}
	assert count == 512
}

fn test_srgb_transfer_preserves_empty_geometry_and_rejects_invalid_samples() {
	for direction in [SrgbTransferDirection.from_linear, .to_linear] {
		assert srgb_transfer(FloatPlane{}, direction)!.samples.len == 0
		if _ := srgb_transfer(FloatPlane{ width: 1, height: 1 }, direction) { assert false }
		for invalid in [u32(0x7f800000), 0xff800000, 0x7fc00000] {
			if _ := srgb_transfer(FloatPlane{ width: 1, height: 1, samples: [math.f32_from_bits(invalid)] }, direction) { assert false }
		}
	}
}
