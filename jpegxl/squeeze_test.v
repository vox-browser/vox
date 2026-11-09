module jpegxl

fn squeeze_test_values(text string) []i32 {
	return text.split(',').map(it.i32())
}

fn test_squeeze_pairs_and_complete_planes_match_scalar_source() {
	mut pairs := 0
	mut planes := 0
	for line in $embed_file('testdata/squeeze.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		if f[0] == 'P' {
			assert f.len == 3
			v := squeeze_test_values(f[1])
			out := modular_squeeze_pair(v[0], v[1], v[2], v[3])
			assert '${out[0]},${out[1]}' == f[2], 'Squeeze pair ${pairs}'
			pairs++
		} else {
			assert f[0] == 'I' && f.len == 7
			dimensions := f[3].split(',').map(it.int())
			mut average := ModularChannel.new(dimensions[0], dimensions[1], none)!
			mut residual := ModularChannel.new(dimensions[2], dimensions[3], none)!
			average.samples = squeeze_test_values(f[4])
			residual.samples = squeeze_test_values(f[5])
			storage := if f[2] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
			out := inverse_modular_squeeze(average, residual, f[1] == '1', storage, ModularShift{ horizontal: 2, vertical: 3 })!
			assert out.samples.map(it.str()).join(',') == f[6], 'Squeeze plane ${planes}'
			assert out.shift == ?ModularShift(ModularShift{ horizontal: 2, vertical: 3 })
			assert out.width == if f[1] == '1' {
				dimensions[0] + dimensions[2]
			} else {
				dimensions[0]
			}
			assert out.height == if f[1] == '1' {
				dimensions[1]
			} else {
				dimensions[1] + dimensions[3]
			}
			planes++
		}
	}
	assert pairs == 8192 && planes == 1024
}

fn test_squeeze_single_tail_empty_planes_and_bad_dimensions() {
	mut average := ModularChannel.new(1, 3, none)!
	average.samples = [i32(65535), 2, -3]
	residual := ModularChannel.new(0, 3, none)!
	assert inverse_modular_squeeze(average, residual, true, .signed32, none)!.samples == average.samples
	assert inverse_modular_squeeze(average, residual, true, .signed16, none)!.samples == [
		i32(-1),
		2,
		-3,
	]
	mut top := ModularChannel.new(3, 1, none)!
	top.samples = average.samples.clone()
	assert inverse_modular_squeeze(top, ModularChannel.new(3, 0, none)!, false, .signed32, none)!.samples == top.samples
	assert inverse_modular_squeeze(ModularChannel.new(0, 0, none)!, ModularChannel.new(0, 0, none)!, true, .signed32, none)!.samples.len == 0
	for dimensions in [[1, 1, 2, 1]!, [3, 1, 1, 1]!, [1, 1, 1, 2]!] {
		if _ := inverse_modular_squeeze(ModularChannel.new(dimensions[0], dimensions[1], none)!, ModularChannel.new(dimensions[2], dimensions[3], none)!, true, .signed32, none) {
			assert false
		}
	}
	if _ := inverse_modular_squeeze(ModularChannel{ width: 1, height: 1 }, ModularChannel.new(1, 1, none)!, false, .signed32, none) {
		assert false
	}
}
