module jpegxl

import encoding.hex

fn test_modular_sections_tiles_and_stream_ids_match_source() {
	mut count := 0
	for line in $embed_file('testdata/modular-groups.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 7
		mut p := new_bit_reader(hex.decode(f[3])!)
		frame := FrameHeader{ width: f[0].u32(), height: f[1].u32(), group_size_shift: f[2].u32(), passes: p.read_passes()!, restoration: RestorationFilter.default() }
		mut infos := []ModularChannelInfo{}
		for item in f[4].split(';') {
			v := item.split(',')
			shift := if v[2] == '-1' {
				?ModularShift(none)
			} else {
				?ModularShift(ModularShift{ horizontal: v[2].u32(), vertical: v[3].u32() })
			}
			infos << ModularChannelInfo{ width: v[0].int(), height: v[1].int(), shift: shift }
		}
		sections := plan_modular_sections(infos, frame)!
		assert sections.map(it.map(it.str()).join(',')).join(';') == f[5], 'Section order ${count}'
		mut records := []string{}
		for section in 1 .. sections.len {
			groups := if section == 1 { frame.num_lf_groups() } else { frame.num_groups() }
			for group in [u64(0), groups / 2, groups - 1] {
				id := if section == 1 {
					frame.modular_lf_stream_id(group)!
				} else {
					frame.modular_hf_stream_id(section - 2, group)!
				}
				for c in sections[section] {
					tile := modular_group_tile(infos[c], frame, section == 1, group)!
					records << '${section},${group},${c},${id},${tile.x},${tile.y},${tile.width},${tile.height}'
				}
			}
		}
		assert records.join(';') == f[6], 'Group rectangles ${count}'
		count++
	}
	assert count == 512
}

fn test_modular_group_invalid_indices_and_empty_tiles() {
	frame := FrameHeader{ width: 257, height: 1, restoration: RestorationFilter.default() }
	info := ModularChannelInfo{ width: 1, height: 1, shift: ModularShift{ horizontal: 9 } }
	assert modular_group_tile(info, frame, false, 1)!.width == 0
	if _ := modular_group_tile(info, frame, false, 2) {
		assert false
	}
	if _ := modular_group_tile(ModularChannelInfo{}, frame, false, 0) {
		assert false
	}
	if _ := frame.modular_lf_stream_id(1) {
		assert false
	}
	if _ := frame.modular_hf_stream_id(1, 0) {
		assert false
	}
	if _ := frame.modular_hf_stream_id(0, 2) {
		assert false
	}
}
