module jpegxl

import math

fn test_spline_dequantization_matches_native_points_coefficients_and_area() {
	mut count := 0
	mut accepted := 0
	mut coincident := 0
	for line in $embed_file('testdata/spline-dequant.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		point := f[1].split(',').map(math.f32_from_bits(it.u32()))
		correlation := f[3].split(',').map(math.f32_from_bits(it.u32()))
		mut deltas := []SplineDelta{}
		if f[5] != '' {
			for delta in f[5].split(';') {
				x, y := delta.all_before(',').i64(), delta.all_after(',').i64()
				deltas << SplineDelta{ x: x, y: y }
			}
		}
		coefficients := f[6].split(',').map(i32(it.int()))
		assert coefficients.len == 128
		mut color := [3][32]i32{}
		mut sigma := [32]i32{}
		for c in 0 .. 3 {
			for i in 0 .. 32 { color[c][i] = coefficients[c * 32 + i] }
		}
		for i in 0 .. 32 { sigma[i] = coefficients[96 + i] }
		quantized := QuantizedSpline{ control_points: deltas, color_dct: color, sigma_dct: sigma }
		if spline := quantized.dequantize(SplinePoint{ x: point[0], y: point[1] }, i32(f[2].int()), correlation[0], correlation[1], f[4].u64()) {
			assert f[7] == 'ok', f[0]
			mut points := []u32{}
			for p in spline.control_points {
				points << math.f32_bits(p.x)
				points << math.f32_bits(p.y)
			}
			assert points == f[8].split(',').map(it.u32()), 'Spline points ${f[0]}'
			mut colors := []u32{}
			for c in 0 .. 3 { colors << spline.color_dct[c][..].map(math.f32_bits(it)) }
			assert colors == f[9].split(',').map(it.u32()), 'Spline color DCT ${f[0]}'
			assert spline.sigma_dct[..].map(math.f32_bits(it)) == f[10].split(',').map(it.u32()), 'Spline sigma DCT ${f[0]}'
			assert spline.estimated_area_reached == f[11].u64(), 'Spline estimated area ${f[0]}'
			if _ := spline.validate_adjacent_points() {
				assert f[12] == '1'
			} else {
				assert f[12] == '0'
				coincident++
			}
			accepted++
		} else {
			assert f[7] == 'err', 'Rejected native spline ${f[0]}: ${err.msg()}'
		}
		count++
	}
	assert count == 896 && accepted == 244 && coincident > 0
}

fn test_spline_dequantization_rejects_nonfinite_context_before_coordinate_casts() {
	quantized := QuantizedSpline{ color_dct: [3][32]i32{}, sigma_dct: [32]i32{} }
	for word in [u32(0x7fc00001), 0x7f800000, 0xff800000] {
		value := math.f32_from_bits(word)
		if _ := quantized.dequantize(SplinePoint{ x: value }, 0, 0, 0, 1024) {
			assert false
		}
		if _ := quantized.dequantize(SplinePoint{}, 0, value, 0, 1024) {
			assert false
		}
	}
}
