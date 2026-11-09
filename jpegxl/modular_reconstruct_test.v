module jpegxl

import encoding.hex

fn reconstruct_test_infos(text string) []ModularChannelInfo {
	mut result := []ModularChannelInfo{}
	for item in text.split(';') {
		v := item.split(',')
		shift := if v[2] == '-1' {
			?ModularShift(none)
		} else {
			?ModularShift(ModularShift{ horizontal: v[2].u32(), vertical: v[3].u32() })
		}
		result << ModularChannelInfo{ width: v[0].int(), height: v[1].int(), shift: shift, bit_depth: BitDepth{ bits_per_sample: v[4].u32() } }
	}
	return result
}

fn reconstruct_test_channels(channels []ModularChannel) string {
	return channels.map(it.samples.map(it.str()).join(',')).join(';')
}

fn test_reverse_transform_graph_matches_complete_source_local_execution() {
	mut count := 0
	for line in $embed_file('testdata/modular-reconstruct.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		storage := if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		infos := reconstruct_test_infos(f[1])
		mut reader := new_bit_reader(hex.decode(f[2])!)
		header := reader.read_modular_group_header()!
		plan := plan_modular_transforms(infos, header, ModularPlanLimits{})!
		mut coded := plan.allocate_coded_channels()!
		values := f[3].split(';')
		assert values.len == coded.len
		for i, text in values {
			input := if text == '' { []i32{} } else { text.split(',').map(it.i32()) }
			assert input.len == coded[i].samples.len
			coded[i].samples = input.clone()
		}
		before := reconstruct_test_channels(coded)
		output := plan.reconstruct(coded, storage)!
		assert '1|${reconstruct_test_channels(output)}' == f[4], 'Composed source transform ${count}'
		assert reconstruct_test_channels(coded) == before
		count++
	}
	assert count == 256
}

fn test_transform_graph_checks_bad_identities_before_reconstruction() {
	for plan in [ModularTransformPlan{ coded: [0] },
		ModularTransformPlan{ buffers: [ModularChannelInfo{}], coded: [0, 0] },
		ModularTransformPlan{ buffers: [ModularChannelInfo{}], outputs: [0] },
		ModularTransformPlan{ buffers: [ModularChannelInfo{}], coded: [0], steps: [ModularTransformStep{ kind: .rct }] }] {
		if _ := plan.allocate_coded_channels() {
			assert false
		}
		if _ := plan.reconstruct([], .signed32) {
			assert false
		}
	}
	info := ModularChannelInfo{ width: 1, height: 1 }
	plan := plan_modular_transforms([info], ModularGroupHeader{}, ModularPlanLimits{})!
	if _ := plan.reconstruct([], .signed32) {
		assert false
	}
	if _ := plan.reconstruct([ModularChannel{}], .signed32) {
		assert false
	}
	assert plan.reconstruct([ModularChannel.new(1, 1, none)!], .signed32)!.len == 1
}

fn test_singleton_squeeze_reconstruction_preserves_the_logical_empty_residual_shape() {
	for horizontal in [false, true] {
		for empty in [false, true] {
			width := if empty { 0 } else if horizontal { 1 } else { 3 }
			height := if horizontal { 3 } else { 1 }
			info := ModularChannelInfo{width: width, height: height, shift: ModularShift{}}
			header := ModularGroupHeader{transforms: [ModularTransform{
				id: .squeeze
				squeezes: [SqueezeParams{horizontal: horizontal, in_place: true, num_channels: 1}]
			}]}
			plan := plan_modular_transforms([info], header, ModularPlanLimits{})!
			mut coded := plan.allocate_coded_channels()!
			assert coded.len == 2
			assert coded[1].width == 0 && coded[1].height == 0
			if !empty { coded[0].samples = [i32(2), 4, 6] }
			output := plan.reconstruct(coded, .signed32)!
			assert output.len == 1
			assert output[0].width == if empty { 0 } else { width }
			assert output[0].height == if empty { 0 } else { height }
			assert output[0].samples == if empty { []i32{} } else { [i32(2), 4, 6] }
		}
	}
}
