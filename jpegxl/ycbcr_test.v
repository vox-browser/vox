module jpegxl

import math

fn test_ycbcr_planes_match_native_pinned_stage() {
	mut count := 0
	for line in $embed_file('testdata/ycbcr.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 4
		input := f[2].split(';').map(FloatPlane{ width: f[0].int(), height: f[1].int(), samples: it.split(',').map(math.f32_from_bits(it.u32())) })
		output := ycbcr_to_rgb_planes(input)!
		assert output.len == 3
		assert output.map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[3], 'YCbCr ${count}'
		assert input.map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[2]
		count++
	}
	assert count == 512
}

fn test_ycbcr_geometry_and_unclipped_output() {
	if _ := ycbcr_to_rgb_planes([]) {
		assert false
	}
	if _ := ycbcr_to_rgb_planes([FloatPlane{}, FloatPlane{},
		FloatPlane{ width: 1, height: 1, samples: [f32(0)] }]) {
		assert false
	}
	assert ycbcr_to_rgb_planes([FloatPlane{}, FloatPlane{}, FloatPlane{}])!.len == 3
	input := [FloatPlane{ width: 1, height: 1, samples: [f32(1)] },
		FloatPlane{ width: 1, height: 1, samples: [f32(0)] },
		FloatPlane{ width: 1, height: 1, samples: [f32(1)] }]
	output := ycbcr_to_rgb_planes(input)!
	assert output[0].samples[0] > 1 && output[1].samples[0] < 0 && output[2].samples[0] > 1
}
