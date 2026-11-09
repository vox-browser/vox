module jpegxl

import encoding.hex

fn plan_test_infos(text string) []ModularChannelInfo {
	mut result := []ModularChannelInfo{}
	for item in text.split(';') {
		v := item.split(',')
		shift := if v[2] == '-1' {
			?ModularShift(none)
		} else {
			?ModularShift(ModularShift{ horizontal: v[2].u32(), vertical: v[3].u32() })
		}
		output := if v[7] == '-1' { ?u32(none) } else { ?u32(v[7].u32()) }
		result << ModularChannelInfo{ width: v[0].int(), height: v[1].int(), shift: shift, bit_depth: BitDepth{ bits_per_sample: v[4].u32(), floating_point: v[5] == '1', exponent_bits: v[6].u32() }, output_channel: output, followed_by_palette: v[8] == '1' }
	}
	return result
}

fn plan_test_info_text(info ModularChannelInfo) string {
	x := if s := info.shift { i64(s.horizontal) } else { i64(-1) }
	y := if s := info.shift { i64(s.vertical) } else { i64(-1) }
	output := if o := info.output_channel { i64(o) } else { i64(-1) }
	return '${info.width},${info.height},${x},${y},${info.bit_depth.bits_per_sample},${if info.bit_depth.floating_point {
		1
	} else {
		0
	}},${info.bit_depth.exponent_bits},${output},${if info.followed_by_palette { 1 } else { 0 }}'
}

fn plan_test_weighted(h WeightedPredictorHeader) string {
	return '${if h.all_default { 1 } else { 0 }},${h.p1c},${h.p2c},${h.p3ca},${h.p3cb},${h.p3cc},${h.p3cd},${h.p3ce},${h.w0},${h.w1},${h.w2},${h.w3}'
}

fn plan_test_text(plan ModularTransformPlan) string {
	mut steps := []string{}
	for step in plan.steps {
		input := step.inputs.map(it.str()).join(',')
		output := step.outputs.map(it.str()).join(',')
		steps << match step.kind {
			.rct { '0|${input}|${output}|${step.rct_type}' }
			.palette {
				'1|${input}|${output}|${step.num_deltas},${int(step.predictor)}|${plan_test_weighted(step.weighted)}'
			}
			.horizontal_squeeze { '2|${input}|${output}' }
			.vertical_squeeze { '3|${input}|${output}' }
		}
	}
	return '${plan.buffers.map(plan_test_info_text(it)).join(';')}|${plan.coded.map(it.str()).join(',')}|${steps.join('~')}|${plan.palette_samples}'
}

fn test_modular_transform_plans_match_source_buffers_order_and_steps() {
	mut count := 0
	mut accepted := 0
	for line in $embed_file('testdata/modular-plan.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 6
		mut reader := new_bit_reader(hex.decode(f[3])!)
		header := reader.read_modular_group_header()!
		assert reader.position == f[4].int()
		result := if plan := plan_modular_transforms(plan_test_infos(f[2]), header, ModularPlanLimits{ max_channels: f[0].int(), max_palette_samples: f[1].u64() }) {
			plan_test_text(plan)
		} else {
			'err'
		}
		assert result == f[5], 'Transform plan ${count}'
		if result != 'err' { accepted++ }
		count++
	}
	assert count == 1024
	assert accepted > 400
}

fn test_modular_plan_rejects_invalid_api_requests_and_preserves_inputs() {
	info := ModularChannelInfo{ width: 1, height: 1, shift: ModularShift{} }
	input := [info, info, info]
	for limits in [ModularPlanLimits{ max_channels: -1 }, ModularPlanLimits{ max_channels: 65537 },
		ModularPlanLimits{ max_buffers: 2 }] {
		if _ := plan_modular_transforms(input, ModularGroupHeader{}, limits) {
			assert false
		}
	}
	for transform in [ModularTransform{ id: .rct, rct_type: 42 },
		ModularTransform{ id: .palette, num_channels: 0 },
		ModularTransform{ id: .squeeze, squeezes: [SqueezeParams{ num_channels: 0 }] },
		ModularTransform{ id: .invalid }] {
		if _ := plan_modular_transforms(input, ModularGroupHeader{ transforms: [transform] }, ModularPlanLimits{}) {
			assert false
		}
	}
	assert input.all(it == info)
	if _ := default_modular_squeeze([]) {
		assert false
	}
	if _ := default_modular_squeeze([ModularChannelInfo{ width: 1, height: 1 }]) {
		assert false
	}
	if _ := default_modular_squeeze([ModularChannelInfo{ width: int(u64(0x7fffffffffffffff)), height: 1, shift: ModularShift{} }]) {
		assert false
	}
	plan := plan_modular_transforms(input, ModularGroupHeader{ transforms: [ModularTransform{ id: .rct }] }, ModularPlanLimits{})!
	assert plan.coded == [3, 4, 5] && plan.outputs == [0, 1, 2]
}
