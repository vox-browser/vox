module jpegxl

import math

fn test_noise_application_matches_native_neon_words_and_exact_lut_full_precision() {
	mut count := 0
	mut words := 0
	mut full := 0
	for line in $embed_file('testdata/noise-application.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		values := f[1].split(',').map(math.f32_from_bits(it.u32()))
		mut lut := [8]f32{}
		for i in 0 .. 8 { lut[i] = values[i] }
		cf := f[2].split(',')
		correlation := ColorCorrelationParams{ color_factor: cf[0].u32(), base_correlation_x: math.f32_from_bits(cf[1].u32()),
			base_correlation_b: math.f32_from_bits(cf[2].u32()), ytox_lf: i32(cf[3].int()), ytob_lf: i32(cf[4].int()) }
		mut input := [3]FloatPlane{}
		mut random := [3]FloatPlane{}
		for c in 0 .. 3 {
			input[c] = FloatPlane{ width: 32, height: 1, samples: f[c + 3].split(',').map(math.f32_from_bits(it.u32())) }
			random[c] = FloatPlane{ width: 32, height: 1, samples: f[c + 6].split(',').map(math.f32_from_bits(it.u32())) }
		}
		before := input[0].samples.clone()
		result := add_noise_planes(input, random, NoiseParams{ lut: lut }, correlation, .bfloat16)!
		for c in 0 .. 3 {
			assert result[c].samples.map(math.f32_bits(it)) == f[c + 9].split(',').map(it.u32()), 'Noise application ${f[0]}, channel ${c}'
			words += result[c].samples.len
		}
		assert input[0].samples == before
		if f[0].int() >= 512 {
			// These native LUTs are exactly representable in BF16. Both source
			// precision paths use identical table values for this cohort.
			for value in lut { assert math.f32_bits(value) & u32(0xffff) == 0 }
			exact := add_noise_planes(input, random, NoiseParams{ lut: lut }, correlation, .full)!
			for c in 0 .. 3 { assert exact[c].samples.map(math.f32_bits(it)) == result[c].samples.map(math.f32_bits(it)) }
			full++
		}
		count++
	}
	assert count == 768 && words == 73728 && full == 256
}

fn test_noise_application_rejects_bad_buffers_and_nonfinite_parameters() {
	plane := FloatPlane{ width: 2, height: 1, samples: [f32(0), 1] }
	input := [plane, plane, plane]!
	bad := FloatPlane{ ...plane, width: 1 }
	if _ := add_noise_planes(input, [bad, plane, plane]!, NoiseParams{}, ColorCorrelationParams{}, .bfloat16) { assert false }
	if _ := add_noise_planes(input, input, NoiseParams{}, ColorCorrelationParams{ color_factor: 0 }, .full) { assert false }
	mut lut := [8]f32{}
	lut[0] = math.f32_from_bits(u32(0x7f800000))
	if _ := add_noise_planes(input, input, NoiseParams{ lut: lut }, ColorCorrelationParams{}, .full) { assert false }
	assert add_noise_planes(input, input, NoiseParams{}, ColorCorrelationParams{}, .full)![0].samples == plane.samples
}
