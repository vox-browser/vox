module jpegxl

import encoding.hex

fn prediction_values(text string) []i32 {
	return if text == '' { []i32{} } else { text.split(',').map(it.i32()) }
}

fn test_modular_properties_and_sample_reconstruction_match_source() {
	mut properties := []i32{len: 256}
	mut weighted := WeightedPredictorState.new(WeightedPredictorHeader{}, 1)!
	mut enabled := false
	mut width := 1
	mut step := 0
	mut counts := map[string]int{}
	for line in $embed_file('testdata/modular-prediction.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		counts[f[0]]++
		match f[0] {
			'M' {
				assert make_modular_pixel(f[1].i32(), f[2].u32(), f[3].i64()) == f[4].i32()
			}
			'H' {
				width = f[1].int()
				enabled = f[3] == '1'
				mut reader := new_bit_reader(hex.decode(f[4])!)
				weighted = WeightedPredictorState.new(reader.read_weighted_predictor_header()!, width)!
				properties = []i32{len: 256}
				statics := prediction_values(f[5])
				properties[0] = statics[0]
				properties[1] = statics[1]
				step = 0
			}
			'P' {
				x := step % width
				y := step / width
				if x == 0 { properties[9] = 0 }
				v := prediction_values(f[1])
				data := PredictionData{ left: v[0], top: v[1], toptop: v[2], topleft: v[3], topright: v[4], leftleft: v[5], toprightright: v[6] }
				prediction := if enabled {
					weighted.predict_and_property(x, y, data)!
				} else {
					WeightedPrediction{}
				}
				compute_modular_properties(data, x, y, prediction_values(f[3]), prediction, mut properties)!
				assert prediction.value == f[4].i64()
				assert properties.map(it.str()).join(',') == f[5], 'Properties transcript ${counts['H']}, step ${step}'
				if enabled { weighted.update_errors(f[2].i32(), x, y)! }
				step++
			}
			else {
				assert false
			}
		}
	}
	assert counts['M'] == 4096 && counts['H'] == 32 && counts['P'] == 1536
}

fn test_modular_prediction_checks_properties_before_mutation() {
	for length in [0, 15, 257] {
		mut props := []i32{len: length, init: 7}
		mut rejected := false
		compute_modular_properties(PredictionData{}, 0, 0, [], WeightedPrediction{}, mut props) or { rejected = true }
		assert rejected && props.all(it == 7)
	}
	mut props := []i32{len: 16, init: 7}
	mut rejected := false
	compute_modular_properties(PredictionData{}, 0, 0, [i32(1)], WeightedPrediction{}, mut props) or { rejected = true }
	assert rejected && props.all(it == 7)
	for pos in [[-1, 0]!, [0, -1]!] {
		rejected = false
		compute_modular_properties(PredictionData{}, pos[0], pos[1], [], WeightedPrediction{}, mut props) or { rejected = true }
		assert rejected && props.all(it == 7)
	}
	tree := ModularTree{ nodes: [ModularTreeNode{ threshold: 1, left: 1, right: 2 },
		ModularTreeNode{ is_leaf: true, predictor: .west, offset: -2, multiplier: 3, context: 7 },
		ModularTreeNode{ is_leaf: true, predictor: .weighted, offset: 1, multiplier: 5, context: 9 }] }
	assert tree.predict_modular(PredictionData{ left: 42 }, 0, [i32(2)])! == ModularPrediction{ guess: 40, multiplier: 3, context: 7 }
	assert tree.predict_modular(PredictionData{}, 9223372036854775807, [i32(1)])!.guess == i64(-9223372036854775807 - 1)
}
