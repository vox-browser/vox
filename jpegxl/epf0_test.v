module jpegxl

import math

fn test_epf0_matches_pinned_native_stage() {
	mut count := 0
	for line in $embed_file('testdata/epf0.tsv').to_string().split_into_lines() {
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
		output := epf0_planes(input, params, sigma, f[2].u32(), f[3].u32())!
		assert output.len == 3 && output.all(it.width == f[0].int() && it.height == f[1].int())
		assert output.map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[9], 'EPF 0 case ${count}'
		assert input.map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[8]
		count++
	}
	assert count == 512
}
