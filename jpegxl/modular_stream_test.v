module jpegxl

import encoding.hex

fn stream_test_infos(text string) []ModularChannelInfo {
	mut result := []ModularChannelInfo{}
	for item in text.split(';') {
		v := item.split(',')
		shift := if v[2] == '-1' {
			?ModularShift(none)
		} else {
			?ModularShift(ModularShift{ horizontal: v[2].u32(), vertical: v[3].u32() })
		}
		result << ModularChannelInfo{ width: v[0].int(), height: v[1].int(), shift: shift }
	}
	return result
}

fn test_complete_modular_streams_match_pinned_source() {
	mut count := 0
	mut accepted := 0
	for line in $embed_file('testdata/modular-stream.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 8
		storage := if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		mut provided := ?ModularGroupHeader(none)
		if f[3] != '-' {
			mut h := new_bit_reader(hex.decode(f[3])!)
			provided = h.read_modular_group_header()!
		}
		mut global := ?ModularTree(none)
		if f[4] != '-' {
			mut g := new_bit_reader(hex.decode(f[4])!)
			global = g.read_modular_tree(100)!
		}
		mut reader := new_bit_reader(hex.decode(f[5])!)
		result := if output := reader.decode_modular_stream(stream_test_infos(f[2]), storage, f[1].u32(), provided, global) {
			output.map('${it.width},${it.height}:${it.samples.map(it.str()).join(',')}').join(';')
		} else {
			'err'
		}
		assert result == f[7], 'Complete modular stream ${count}'
		// The direct reader does not model the source's cached cursor after errors.
		if f[7] != 'err' {
			assert reader.position == f[6].int()
			accepted++
		}
		count++
	}
	assert count == 303 && accepted == 234
}

fn test_modular_stream_shape_limits_and_missing_global_tree() {
	assert modular_stream_limits([ModularChannelInfo{ width: 1000, height: 0 },
		ModularChannelInfo{ width: 4, height: 4 }])!.max_channels == 76
	mut reader := new_bit_reader([u8(3)]) // global tree, default weighted header, no transforms
	if _ := reader.decode_modular_stream([ModularChannelInfo{ width: 1, height: 1 }], .signed32, 0, none, none) {
		assert false
	}
	assert reader.position == 4
	mut empty := new_bit_reader([])
	result := empty.decode_modular_stream([ModularChannelInfo{ width: 0, height: 8 }], .signed16, 0, ModularGroupHeader{ use_global_tree: true }, none)!
	assert result.len == 1 && result[0].width == 0 && result[0].height == 0
	assert empty.position == 0
	if _ := empty.decode_modular_stream([ModularChannelInfo{ width: -1, height: 1 }], .signed32, 0, none, none) {
		assert false
	}
	assert empty.position == 0
}
