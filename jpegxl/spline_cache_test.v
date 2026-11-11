module jpegxl

import math

fn test_spline_cache_matches_native_segments_and_ordered_row_membership() {
	mut count := 0
	mut accepted := 0
	mut segments := 0
	mut entries := 0
	for line in $embed_file('testdata/spline-cache.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		c := f[6].split(',')
		correlation := ColorCorrelationParams{
			color_factor:       c[0].u32()
			base_correlation_x: math.f32_from_bits(c[1].u32())
			base_correlation_b: math.f32_from_bits(c[2].u32())
			ytox_lf:            i32(c[3].int())
			ytob_lf:            i32(c[4].int())
		}
		mut starts := []SplinePoint{}
		for point in f[7].split(';') {
			p := point.split(',').map(math.f32_from_bits(it.u32()))
			starts << SplinePoint{ x: p[0], y: p[1] }
		}
		mut deltas := f[8].split('|')
		if f[8] == '' { deltas = []string{len: starts.len} }
		coefficients := f[9].split('|')
		mut quantized := []QuantizedSpline{}
		for i in 0 .. starts.len {
			mut points := []SplineDelta{}
			if deltas[i] != '' {
				for delta in deltas[i].split(';') {
					points << SplineDelta{ x: delta.all_before(',').i64(), y: delta.all_after(',').i64() }
				}
			}
			values := coefficients[i].split(',').map(i32(it.int()))
			assert values.len == 128
			mut color := [3][32]i32{}
			mut sigma := [32]i32{}
			for channel in 0 .. 3 {
				for j in 0 .. 32 { color[channel][j] = values[channel * 32 + j] }
			}
			for j in 0 .. 32 { sigma[j] = values[96 + j] }
			quantized << QuantizedSpline{ control_points: points, color_dct: color, sigma_dct: sigma }
		}
		set := Splines{ quantization_adjustment: i32(f[5].int()), splines: quantized, starting_points: starts }
		if cache := set.create_draw_cache(f[1].int(), f[2].int(), correlation, f[3] == '1', f[4] == '1') {
			assert f[10] == 'ok', f[0]
			assert cache.is_initialized() && cache.width == f[1].int() && cache.height == f[2].int()
			mut actual := []u32{}
			for segment in cache.segments {
				for value in [segment.center_x, segment.center_y, segment.maximum_distance,
					segment.inv_sigma, segment.sigma_over_4_times_intensity, segment.color[0],
					segment.color[1], segment.color[2]] {
					actual << if math.is_nan(value) {
						u32(0x7fc00000)
					} else {
						math.f32_bits(value)
					}
				}
			}
			expected := if f[11] == '' { []u32{} } else { f[11].split(',').map(it.u32()) }
			assert actual.len == expected.len, 'Spline cache segment count ${f[0]}'
			for i, word in actual {
				assert word == expected[i], 'Spline cache ${f[0]}, segment ${i / 8}, field ${i % 8}'
			}
			expected_starts := f[12].split(',').map(it.int())
			assert cache.row_starts.len == expected_starts.len
			for i, value in cache.row_starts {
				assert value == expected_starts[i], 'Spline cache ${f[0]}, row start ${i}'
			}
			expected_indices := if f[13] == '' { []int{} } else { f[13].split(',').map(it.int()) }
			assert cache.row_indices.len == expected_indices.len, 'Spline cache row membership ${f[0]}'
			for i, value in cache.row_indices {
				assert value == expected_indices[i], 'Spline cache ${f[0]}, row index ${i}'
			}
			segments += cache.segments.len
			entries += cache.row_indices.len
			accepted++
		} else {
			assert f[10] == 'err', 'Rejected native spline cache ${f[0]}: ${err.msg()}'
		}
		count++
	}
	assert count == 256 && accepted == 234 && segments == 3341 && entries == 57792
}

fn test_spline_cache_rejects_invalid_shapes_before_geometry() {
	set := Splines{}
	for dimensions in [[0, 1], [1, 0], [65536, 65536]] {
		if _ := set.create_draw_cache(dimensions[0], dimensions[1], ColorCorrelationParams{}, false, false) {
			assert false
		}
	}
	quantized := QuantizedSpline{ color_dct: [3][32]i32{}, sigma_dct: [32]i32{} }
	invalid := Splines{ splines: [quantized] }
	if _ := invalid.create_draw_cache(32, 32, ColorCorrelationParams{}, false, false) {
		assert false
	}
	assert !SplineDrawCache{}.is_initialized()
}
