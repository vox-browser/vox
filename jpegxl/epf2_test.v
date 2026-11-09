module jpegxl

import math

fn test_epf2_matches_pinned_native_stage() {
	mut count := 0
	for line in $embed_file('testdata/epf2.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 10
		params := EpfParameters{
			sigma_scale:           math.f32_from_bits(f[4].u32())
			border_sad_multiplier: math.f32_from_bits(f[5].u32())
			channel_scale:         [
				math.f32_from_bits(f[6].split(',')[0].u32()),
				math.f32_from_bits(f[6].split(',')[1].u32()),
				math.f32_from_bits(f[6].split(',')[2].u32()),
			]!
		}
		p := f[7].split(':')
		sigma := if p[0] == 'C' {
			EpfSigma{ inverse_sigma: math.f32_from_bits(p[1].u32()) }
		} else {
			EpfSigma{ blocks: FloatPlane{ width: p[1].split(',')[0].int(), height: p[1].split(',')[1].int(), samples: p[2].split(',').map(math.f32_from_bits(it.u32())) } }
		}
		input := f[8].split(';').map(FloatPlane{ width: f[0].int(), height: f[1].int(), samples: it.split(',').map(math.f32_from_bits(it.u32())) })
		output := epf2_planes(input, params, sigma, f[2].u32(), f[3].u32())!
		assert output.len == 3 && output.all(it.width == f[0].int() && it.height == f[1].int())
		assert output.map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[9], 'EPF 2 case ${count}'
		assert input.map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[8]
		count++
	}
	assert count == 512
}

fn test_epf_sigma_shape_bounds_and_owned_bypass() {
	assert math.f32_bits(EpfSigma.modular(2)!.inverse_sigma) == 3205887514
	if _ := EpfSigma.modular(0) {
		assert false
	}
	if _ := EpfSigma.modular(f32(math.inf(1))) {
		assert false
	}
	parameters := EpfParameters.default(6.5)
	if _ := epf2_planes([], parameters, EpfSigma{}, 0, 0) {
		assert false
	}
	mut samples := [f32(0), 1, 2]
	input := []FloatPlane{len: 3, init: FloatPlane{ width: 3, height: 1, samples: samples }}
	output := epf2_planes(input, parameters, EpfSigma{ inverse_sigma: -10000 }, 4294967295, 4294967295)!
	samples[0] = 100
	assert output.all(it.samples == [f32(0), 1, 2])
	if _ := epf2_planes(input, parameters, EpfSigma{ blocks: FloatPlane{} }, 0, 0) {
		assert false
	}
	if _ := epf2_planes(input, parameters, EpfSigma{ inverse_sigma: f32(math.nan()) }, 0, 0) {
		assert false
	}
	assert epf2_planes([FloatPlane{}, FloatPlane{}, FloatPlane{}], parameters, EpfSigma{}, 0, 0)!.len == 3
}
