module jpegxl

fn hf_metadata_stream_test_tree(value i32, route bool) !ModularTree {
	mut reader := new_bit_reader([u8(0xf2), 1])
	histograms := reader.read_histograms(if route { 2 } else { 1 }, true)!
	assert (histograms.single_symbol(0) or { u32(0xffffffff) }) == 0
	return if route {
		ModularTree{ nodes: [ModularTreeNode{ property: 1, threshold: 5, left: 1, right: 2 },
			ModularTreeNode{ is_leaf: true, multiplier: 1, offset: value, context: 0 },
			ModularTreeNode{ is_leaf: true, multiplier: 1, offset: value + 1, context: 1 }],
			histograms: histograms, num_properties: 2 }
	} else {
		ModularTree{ nodes: [ModularTreeNode{ is_leaf: true, multiplier: 1, offset: value }],
			histograms: histograms, num_properties: 1 }
	}
}

fn hf_metadata_stream_test_packet(count int, count_bits int, leading int) []u8 {
	// Prefix the declared transform count and the four-bit modular header:
	// use global tree, default weighted predictor, zero transforms.
	encoded := (u64(count - 1) << leading) | (u64(3) << (leading + count_bits))
	return []u8{len: (leading + count_bits + 4 + 7) / 8, init: u8(encoded >> (index * 8))}
}

fn test_hf_metadata_stream_reads_count_and_global_entropy_at_unaligned_positions() {
	for size in [[1, 1], [3, 2], [8, 9], [32, 32]] {
		w := size[0]
		h := size[1]
		frame := FrameHeader{ width: u32(w * 8), height: u32(h * 8), restoration: RestorationFilter.default() }
		for storage in [ModularStorage.signed16, .signed32] {
			for value in i32(0) .. i32(4) {
				leading := int(value) + 1
				bits := ceil_log2(w * h)
				mut reader := new_bit_reader(hf_metadata_stream_test_packet(w * h, bits, leading))
				reader.read(leading)!
				result := reader.read_hf_metadata(frame, 0, BitDepth{ bits_per_sample: 8 }, storage, hf_metadata_stream_test_tree(value, false)!)!
				assert result.width == w && result.height == h
				assert result.colors.y_to_x.all(it == value) && result.colors.y_to_b.all(it == value)
				assert result.raw_quant.all(it == value + 1)
				assert result.transform_ids.all(it == u8(value) | 128)
				assert result.sharpness.all(it == u8(value))
				assert reader.position == leading + bits + 4
			}
		}
	}
}

fn test_hf_metadata_stream_uses_lf_group_local_geometry_and_stream_identity() {
	frame := FrameHeader{ width: 2065, height: 33, restoration: RestorationFilter.default() }
	assert frame.num_lf_groups() == 2
	assert frame.lf_metadata_stream_id(0)! == 5 && frame.lf_metadata_stream_id(1)! == 6
	mut reader := new_bit_reader(hf_metadata_stream_test_packet(16, 4, 0))
	result := reader.read_hf_metadata(frame, 1, BitDepth{ bits_per_sample: 8 }, .signed32, hf_metadata_stream_test_tree(1, true)!)!
	assert result.width == 3 && result.height == 5
	assert result.transform_ids.len == 15 && result.transform_ids.all(it == 129)
	assert result.raw_quant.all(it == 2) && result.sharpness.all(it == 1)
	assert reader.position == 8
}

fn test_hf_metadata_stream_rejects_bad_group_geometry_and_missing_tree() {
	frame := FrameHeader{ width: 8, height: 8, restoration: RestorationFilter.default() }
	for invalid in [FrameHeader{ ...frame, width: 0 }, FrameHeader{ ...frame, encoding: .modular },
		FrameHeader{ ...frame, group_size_shift: 2 }] {
		mut reader := new_bit_reader([u8(3)])
		if _ := reader.read_hf_metadata(invalid, 0, BitDepth{ bits_per_sample: 8 }, .signed32, none) { assert false }
		assert reader.position == 0
	}
	mut invalid_group := new_bit_reader([u8(3)])
	if _ := invalid_group.read_hf_metadata(frame, 1, BitDepth{ bits_per_sample: 8 }, .signed32, none) { assert false }
	assert invalid_group.position == 0
	mut absent := new_bit_reader([u8(3)])
	if _ := absent.read_hf_metadata(frame, 0, BitDepth{ bits_per_sample: 8 }, .signed32, none) { assert false }
	assert absent.position == 4
	mut truncated := new_bit_reader([]u8{})
	if _ := truncated.read_hf_metadata(frame, 0, BitDepth{ bits_per_sample: 8 }, .signed32, hf_metadata_stream_test_tree(0, false)!) { assert false }
}
