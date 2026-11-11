module jpegxl

import encoding.hex
import math.bits

fn predictor_test_values(text string) []i32 {
	return text.split(',').map(it.i32())
}

fn predictor_test_data(text string) PredictionData {
	v := predictor_test_values(text)
	assert v.len == 7
	return PredictionData{ left: v[0], top: v[1], toptop: v[2], topleft: v[3], topright: v[4], leftleft: v[5], toprightright: v[6] }
}

fn predictor_test_text(d PredictionData) string {
	return '${d.left},${d.top},${d.toptop},${d.topleft},${d.topright},${d.leftleft},${d.toprightright}'
}

fn predictor_test_rows(rows WeightedPredictorRows) string {
	mut result := [rows.errors.map(it.str()).join(',')]
	for i in 0 .. 4 {
		result << rows.predictor_errors.map(i32(it[i]).str()).join(',')
	}
	return result.join(';')
}

fn test_modular_predictors_and_weighted_state_match_unchanged_source() {
	mut header := WeightedPredictorHeader{}
	mut state := WeightedPredictorState.new(header, 1)!
	mut saved := WeightedPredictorRows{}
	mut case_id := -1
	mut counts := map[string]int{}
	for line in $embed_file('testdata/predictors.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		counts[f[0]]++
		match f[0] {
			'P' {
				data := predictor_test_data(f[1])
				mut results := []string{}
				for id in 0 .. 14 {
					predictor := predictor_from_id(u32(id))!
					results << '${predictor.predict_one(data, f[2].i64())},${if predictor.requires_full_row() {
						1
					} else {
						0
					}}'
				}
				assert results.join(';') == f[3], 'Scalar predictors ${counts['P']}'
			}
			'G' {
				data := PredictionData.from_rows(predictor_test_values(f[3]), predictor_test_values(f[4]), predictor_test_values(f[5]), f[1].int(), f[2].int())!
				assert predictor_test_text(data) == f[6]
			}
			'I' {
				data := predictor_test_data(f[4]).update_for_interior_row(predictor_test_values(f[5]), predictor_test_values(f[6]), f[1].int(), f[2].i32(), f[3] == '1')!
				assert predictor_test_text(data) == f[7]
			}
			'H' {
				case_id = f[1].int()
				assert case_id == counts['H'] - 1
				mut reader := new_bit_reader(hex.decode(f[3])!)
				header = reader.read_weighted_predictor_header()!
				state = WeightedPredictorState.new(header, f[2].int())!
				saved = WeightedPredictorRows{}
			}
			'W' {
				assert case_id == f[1].int()
				pred := state.predict_and_property(f[2].int(), f[3].int(), predictor_test_data(f[5]))!
				assert '${pred.value},${pred.property}' == f[6], 'Weighted predictor case ${case_id}, step ${counts['W']}'
				state.update_errors(f[4].i32(), f[2].int(), f[3].int())!
			}
			'S' {
				assert case_id == f[1].int()
				saved = state.save_rows()
				assert predictor_test_rows(saved) == f[2], 'Saved error rows case ${case_id}'
			}
			'R' {
				assert case_id == f[1].int()
				state = WeightedPredictorState.new(header, state.width)!
				state.restore_rows(saved)!
			}
			else {
				assert false, 'Unknown predictor reference operation'
			}
		}
	}
	assert counts['P'] == 4112
	assert counts['G'] == 306
	assert counts['I'] == 396
	assert counts['H'] == 120
	assert counts['W'] == 11520
	assert counts['S'] == 360
	assert counts['R'] == 240
}

fn test_predictor_signed_rounding_ties_and_bounds() {
	assert Predictor.average_west_north.predict_one(PredictionData{ left: -3, top: 0 }, 0) == -1
	assert Predictor.select.predict_one(PredictionData{ left: 4, top: 8, topleft: 6 }, 0) == 8
	if _ := predictor_from_id(14) {
		assert false
	}
	for width in [-1, 0, 1048577] {
		if _ := WeightedPredictorState.new(WeightedPredictorHeader{}, width) {
			assert false
		}
	}
	for header in [WeightedPredictorHeader{ p1c: 32 }, WeightedPredictorHeader{ w3: 16 }] {
		if _ := WeightedPredictorState.new(header, 1) {
			assert false
		}
	}
	if _ := PredictionData.from_rows([], [], [], 0, 0) {
		assert false
	}
	if _ := PredictionData.from_rows([i32(0)], [], [], 0, 1) {
		assert false
	}
	if _ := PredictionData.from_rows([i32(0)], [i32(0)], [], 0, 2) {
		assert false
	}
	if _ := PredictionData{}.update_for_interior_row([i32(0)], [], 0, 0, false) {
		assert false
	}
	if _ := PredictionData{}.update_for_interior_row([i32(0), 0, 0, 0, 0], [], int(u64(0x7fffffffffffffff)), 0, false) {
		assert false
	}
	mut state := WeightedPredictorState.new(WeightedPredictorHeader{}, 1)!
	for x in [-1, 1] {
		if _ := state.predict_and_property(x, 0, PredictionData{}) {
			assert false
		}
		mut rejected := false
		state.update_errors(0, x, 0) or { rejected = true }
		assert rejected
	}
	if _ := state.predict_and_property(0, -1, PredictionData{}) {
		assert false
	}
	mut rejected := false
	state.update_errors(0, 0, -1) or { rejected = true }
	assert rejected
	mut other := WeightedPredictorState.new(WeightedPredictorHeader{}, 2)!
	before := predictor_test_rows(other.save_rows())
	rejected = false
	other.restore_rows(state.save_rows()) or { rejected = true }
	assert rejected
	assert predictor_test_rows(other.save_rows()) == before
}

// The weighted predictor's floor(log2) agrees with the table-based bit length
// at every power-of-two boundary, and is 0 for 0 and 1.
fn test_predictor_floor_log2_matches_bit_length() {
	assert predictor_floor_log2(0) == 0 && predictor_floor_log2(1) == 0
	for shift in 1 .. 64 {
		power := u64(1) << shift
		for value in [power - 1, power, power + 1] {
			if value > 1 { assert predictor_floor_log2(value) == bits.len_64(value) - 1 }
		}
	}
	assert predictor_floor_log2(max_u64) == 63
}
