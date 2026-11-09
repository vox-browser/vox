module jpegxl

import encoding.hex

fn palette_test_values(text string) []i32 {
	return if text == '' { []i32{} } else { text.split(',').map(it.i32()) }
}

fn test_palette_lookup_and_complete_expansion_match_source() {
	mut lookups := 0
	mut expansions := 0
	for line in $embed_file('testdata/palette.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		if f[0] == 'L' {
			assert f.len == 8
			storage := if f[3] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
			mut palette := ModularChannel.new(f[4].int(), 5, none)!
			palette.samples = palette_test_values(f[5])
			mut output := []string{}
			for index in palette_test_values(f[6]) {
				output << lookup_modular_palette(palette, f[2].int(), f[1].u32(), index, storage)!.str()
			}
			assert output.join(',') == f[7], 'Palette lookup ${lookups}'
			lookups++
		} else {
			assert f[0] == 'P' && f.len == 9
			storage := if f[2] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
			dimensions := f[3].split(',').map(it.int())
			depths := f[4].split(',').map(it.u32())
			mut palette := ModularChannel.new(dimensions[2], depths.len, none)!
			palette.samples = palette_test_values(f[6])
			mut indices := ModularChannel.new(dimensions[0], dimensions[1], ModularShift{ horizontal: 3, vertical: 2 })!
			indices.samples = palette_test_values(f[7])
			mut reader := new_bit_reader(hex.decode(f[5])!)
			header := reader.read_weighted_predictor_header()!
			output := inverse_modular_palette(indices, palette, depths, u32(dimensions[3]), predictor_from_id(f[1].u32())!, header, storage, dimensions[4] == 1)!
			assert output.map(it.samples.map(it.str()).join(',')).join(';') == f[8], 'Palette expansion ${expansions}'
			assert output.all(it.shift == indices.shift)
			expansions++
		}
	}
	assert lookups == 360 && expansions == 224
}

fn test_palette_expansion_bounds_and_input_ownership() {
	mut indices := ModularChannel.new(1, 1, none)!
	indices.samples[0] = -1
	palette := ModularChannel.new(0, 0, none)!
	assert lookup_modular_palette(palette, 3, 8, -1, .signed32)! == 0
	if _ := lookup_modular_palette(palette, -1, 8, 0, .signed32) {
		assert false
	}
	if _ := inverse_modular_palette(indices, palette, [], 0, .zero, WeightedPredictorHeader{}, .signed32, false) {
		assert false
	}
	if _ := inverse_modular_palette(indices, ModularChannel.new(1, 1, none)!, [u32(8), 8], 0, .zero, WeightedPredictorHeader{}, .signed32, false) {
		assert false
	}
	if _ := inverse_modular_palette(indices, palette, [u32(8)], 0, .weighted, WeightedPredictorHeader{ w0: 16 }, .signed32, false) {
		assert false
	}
	output := inverse_modular_palette(indices, palette, [u32(8), 8, 8, 8], 0, .zero, WeightedPredictorHeader{}, .signed32, false)!
	assert output.len == 4 && output.all(it.samples == [i32(0)])
	assert indices.samples == [i32(-1)]
	empty := ModularChannel.new(0, 4, none)!
	assert inverse_modular_palette(empty, palette, [u32(8)], 0, .zero, WeightedPredictorHeader{}, .signed32, false)![0].samples.len == 0
}
