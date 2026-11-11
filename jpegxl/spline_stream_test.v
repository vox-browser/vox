module jpegxl

import crypto.sha256
import encoding.hex
import math

fn test_spline_streams_match_native_state_consumption_and_errors() {
	mut count := 0
	mut accepted := 0
	mut zero_points := 0
	mut maximum_points := 0
	mut adjustments := [2]bool{}
	for line in $embed_file('testdata/spline-streams.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		mut reader := new_bit_reader(hex.decode(f[1])!)
		if state := reader.read_splines(f[2].u32()) {
			assert f[3] != 'err', f[0]
			assert reader.position == f[3].int(), f[0]
			assert int(state.quantization_adjustment) == f[4].int()
			assert state.splines.len == f[5].int() && state.starting_points.len == state.splines.len
			mut starts := []string{}
			for point in state.starting_points {
				starts << '${math.f32_bits(point.x)},${math.f32_bits(point.y)}'
			}
			mut deltas := []string{}
			mut coefficients := []string{}
			mut points := 0
			for spline in state.splines {
				deltas << spline.control_points.map('${it.x},${it.y}').join(';')
				mut dct := []string{cap: 128}
				for c in 0 .. 3 { dct << spline.color_dct[c][..].map(it.str()) }
				dct << spline.sigma_dct[..].map(it.str())
				coefficients << dct.join(',')
				points += spline.control_points.len
			}
			assert points == f[6].int()
			for i, field in [starts.join(';'), deltas.join('|'), coefficients.join('|')] {
				assert sha256.sum(field.bytes()).hex() == f[7 + i], 'Spline stream ${f[0]}, field ${i}'
			}
			if points == 0 { zero_points++ }
			if points > maximum_points { maximum_points = points }
			if state.quantization_adjustment == i32(-2147483647 - 1) { adjustments[0] = true }
			if state.quantization_adjustment == i32(2147483647) { adjustments[1] = true }
			accepted++
		} else {
			assert f[3] == 'err', 'Rejected native spline stream ${f[0]}: ${err.msg()}'
		}
		count++
	}
	assert count == 3044 && accepted == 536 && zero_points > 0 && maximum_points == 128 && adjustments[..].all(it)
}
