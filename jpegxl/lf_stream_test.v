module jpegxl

fn lf_stream_test_tree(routed bool) !ModularTree {
	mut reader := new_bit_reader([u8(0xf2), 1])
	histograms := reader.read_histograms(if routed { 2 } else { 3 }, true)!
	return if routed {
		ModularTree{ nodes: [ModularTreeNode{ property: 1, threshold: 2, left: 1, right: 2 },
			ModularTreeNode{ is_leaf: true, multiplier: 1, offset: 0, context: 0 },
			ModularTreeNode{ is_leaf: true, multiplier: 1, offset: 1, context: 1 }],
			histograms: histograms, num_properties: 2 }
	} else {
		ModularTree{ nodes: [ModularTreeNode{ property: 0, threshold: 0, left: 1, right: 2 },
			ModularTreeNode{ property: 0, threshold: 1, left: 3, right: 4 },
			ModularTreeNode{ is_leaf: true, multiplier: 1, offset: 4, context: 0 },
			ModularTreeNode{ is_leaf: true, multiplier: 1, offset: 6, context: 2 },
			ModularTreeNode{ is_leaf: true, multiplier: 1, offset: 2, context: 1 }],
			histograms: histograms, num_properties: 1 }
	}
}

fn lf_stream_test_context() VarDctLfContext {
	return VarDctLfContext{
		quantizer: QuantizerParams{ global_scale: 65536, quant_lf: 1 }
		lf_quant: LfQuantFactors{ quant_factors: [f32(1), 2, 4]! }
		color_correlation: ColorCorrelationParams{ base_correlation_b: 0 }
		block_context: BlockContextMap{ lf_thresholds: [[i32(1), 2], [i32(3)], [i32(4), 6]]!, num_lf_contexts: 18 }
	}
}

fn test_vardct_lf_stream_preserves_coded_channel_order_sampling_and_extra_precision() {
	for mode in 0 .. 4 {
		horizontal := if mode == 1 || mode == 2 { u32(1) } else { u32(0) }
		vertical := if mode == 1 || mode == 3 { u32(1) } else { u32(0) }
		frame := FrameHeader{ width: 33, height: 25,
			jpeg_upsampling: [u32(0), u32(mode), u32(0)]!, max_hshift: horizontal, max_vshift: vertical,
			restoration: RestorationFilter.default() }
		for storage in [ModularStorage.signed16, .signed32] {
			for precision in 0 .. 4 {
				leading := (precision + mode) % 8
				encoded := (u32(precision) << leading) | (u32(3) << (leading + 2))
				mut reader := new_bit_reader([u8(encoded), u8(encoded >> 8)])
				reader.read(leading)!
				result := reader.read_vardct_lf(frame, 0, BitDepth{ bits_per_sample: 8 }, lf_stream_test_context(), storage, lf_stream_test_tree(false)!)!
				assert result.width == if horizontal == 0 { 5 } else { 6 }
				assert result.height == 4
				assert result.quant_lf_contexts.all(it == 9)
				for c in 0 .. 3 {
					assert result.planes[c].width == result.width >> frame.hshift(c)!
					assert result.planes[c].height == result.height >> frame.vshift(c)!
					expected := [f32(2), 8, 24][c] / f32(u32(1) << precision)
					assert result.planes[c].samples.all(it == expected)
				}
				assert reader.position == leading + 6
			}
		}
	}
}

fn test_vardct_lf_stream_uses_group_local_geometry_and_vardct_stream_identity() {
	frame := FrameHeader{ width: 2065, height: 33, restoration: RestorationFilter.default() }
	assert frame.vardct_lf_stream_id(0)! == 1 && frame.vardct_lf_stream_id(1)! == 2
	mut reader := new_bit_reader([u8(12)])
	context := VarDctLfContext{ ...lf_stream_test_context(),
		lf_quant: LfQuantFactors{ quant_factors: [f32(1), 1, 1]! },
		block_context: BlockContextMap{ num_lf_contexts: 1 } }
	result := reader.read_vardct_lf(frame, 1, BitDepth{ bits_per_sample: 8 }, context, .signed32, lf_stream_test_tree(true)!)!
	assert result.width == 3 && result.height == 5
	for plane in result.planes { assert plane.samples.len == 15 && plane.samples.all(it == 1) }
	assert reader.position == 6
}

fn test_vardct_lf_stream_rejects_bad_geometry_and_missing_global_tree() {
	frame := FrameHeader{ width: 8, height: 8, restoration: RestorationFilter.default() }
	for invalid in [FrameHeader{ ...frame, width: 0 }, FrameHeader{ ...frame, encoding: .modular },
		FrameHeader{ ...frame, group_size_shift: 2 }] {
		mut reader := new_bit_reader([u8(12)])
		if _ := reader.read_vardct_lf(invalid, 0, BitDepth{ bits_per_sample: 8 }, lf_stream_test_context(), .signed32, none) { assert false }
		assert reader.position == 0
	}
	mut invalid_group := new_bit_reader([u8(12)])
	if _ := invalid_group.read_vardct_lf(frame, 1, BitDepth{ bits_per_sample: 8 }, lf_stream_test_context(), .signed32, none) { assert false }
	assert invalid_group.position == 0
	mut missing := new_bit_reader([u8(12)])
	if _ := missing.read_vardct_lf(frame, 0, BitDepth{ bits_per_sample: 8 }, lf_stream_test_context(), .signed32, none) { assert false }
	assert missing.position == 6
	mut empty := new_bit_reader([]u8{})
	if _ := empty.read_vardct_lf(frame, 0, BitDepth{ bits_per_sample: 8 }, lf_stream_test_context(), .signed32, lf_stream_test_tree(false)!) { assert false }
}
