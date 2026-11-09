module jpegxl

import math

fn test_gaborish_planes_match_native_pinned_stage() {
	mut count := 0
	for line in $embed_file('testdata/gaborish.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 6
		samples := f[4].split(',').map(math.f32_from_bits(it.u32()))
		input := FloatPlane{ width: f[0].int(), height: f[1].int(), samples: samples }
		output := gaborish_plane(input, math.f32_from_bits(f[2].u32()), math.f32_from_bits(f[3].u32()))!
		assert output.width == input.width && output.height == input.height
		assert output.samples.map(math.f32_bits(it).str()).join(',') == f[5], 'Gaborish ${count}'
		assert input.samples.map(math.f32_bits(it).str()).join(',') == f[4]
		count++
	}
	assert count == 512
}

fn test_gaborish_rejects_shapes_and_singular_weights() {
	if _ := gaborish_plane(FloatPlane{ width: 2, height: 2, samples: [f32(1)] }, 0, 0) {
		assert false
	}
	for weights in [[f32(-0.25), 0]!, [f32(math.inf(1)), 0]!, [f32(math.nan()), 0]!] {
		if _ := gaborish_plane(FloatPlane{ width: 1, height: 1, samples: [f32(1)] }, weights[0], weights[1]) {
			assert false
		}
	}
	assert gaborish_plane(FloatPlane{}, 0, 0)!.samples.len == 0
	mut original := []f32{len: 9, init: f32(index)}
	output := gaborish_plane(FloatPlane{ width: 3, height: 3, samples: original }, 0, 0)!
	original[0] = 100
	assert output.samples == []f32{len: 9, init: f32(index)}
}
