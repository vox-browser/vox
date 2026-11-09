module jpegxl

import math

fn test_lf_smoothing_matches_source_scalar_kernel_for_all_plane_words() {
	mut count := 0
	mut words := 0
	for line in $embed_file('testdata/lf-smoothing.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		factors := f[2].split(',').map(math.f32_from_bits(it.u32()))
		mut input := []FloatPlane{}
		for channel in f[3].split(';') {
			input << FloatPlane{ width: f[0].int(), height: f[1].int(), samples: channel.split(',').map(math.f32_from_bits(it.u32())) }
		}
		output := adaptive_lf_smoothing(input, [factors[0], factors[1], factors[2]]!)!
		assert output.len == 3
		for c, channel in f[4].split(';') {
			assert output[c].width == input[c].width && output[c].height == input[c].height
			assert output[c].samples.map(math.f32_bits(it).str()).join(',') == channel, 'LF smoothing ${count}, channel ${c}'
			assert voidptr(output[c].samples.data) != voidptr(input[c].samples.data)
			words += output[c].samples.len
		}
		assert input.map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[3]
		count++
	}
	assert count == 512
	assert words > 300000
}

fn test_lf_smoothing_preserves_borders_and_rejects_invalid_configuration() {
	plane := FloatPlane{ width: 3, height: 3, samples: [f32(1), 1, 1, 1, 2, 1, 1, 1, 1] }
	output := adaptive_lf_smoothing([plane, plane, plane], [f32(8), 8, 8]!)!
	for c in 0 .. 3 {
		for p in [0, 1, 2, 3, 5, 6, 7, 8] {
			assert output[c].samples[p] == 1
		}
		assert output[c].samples[4] > 1 && output[c].samples[4] < 2
	}
	if _ := adaptive_lf_smoothing([plane], [f32(1), 1, 1]!) {
		assert false
	}
	bad_shape := FloatPlane{ width: 3, height: 3, samples: [f32(1)] }
	if _ := adaptive_lf_smoothing([plane, plane, bad_shape], [f32(1), 1, 1]!) {
		assert false
	}
	other := FloatPlane{ width: 1, height: 1, samples: [f32(1)] }
	if _ := adaptive_lf_smoothing([plane, plane, other], [f32(1), 1, 1]!) {
		assert false
	}
	for value in [f32(0), -1, f32(math.inf(1)), f32(math.nan())] {
		if _ := adaptive_lf_smoothing([plane, plane, plane], [f32(1), value, 1]!) {
			assert false
		}
	}
}
