// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Decode already transformed channels using a selected local/global tree.
// Header selection, transform scheduling and partial streaming are separate.
// Indexing is direct: validate_modular_tree bounds every reachable split's
// property below num_properties (at most 256, the property buffer size) and
// every reachable child index; row buffers and references match the channel
// width and validated sample counts.
@[direct_array_access]
pub fn (mut reader BitReader) decode_modular_channels(mut channels []ModularChannel, stream_id u32, weighted_header WeightedPredictorHeader, tree ModularTree, storage ModularStorage) ! {
	if channels.len > 65536 { return error('Too many JPEG XL modular channels') }
	mut total := u64(0)
	mut image_width := 0
	for channel in channels {
		channel.validate()!
		total += u64(channel.samples.len)
		if total > 67108864 { return error('JPEG XL modular sample limit exceeded') }
		if channel.samples.len > 0 && channel.width > image_width { image_width = channel.width }
	}
	if total == 0 { return }
	if tree.nodes.len == 0 { return error('Missing JPEG XL modular tree') }
	validate_modular_tree(tree.nodes, tree.num_properties)!
	for node in tree.nodes {
		if node.is_leaf {
			if node.multiplier == 0 { return error('Invalid JPEG XL modular multiplier') }
			tree.histograms.map_context_to_cluster(int(node.context))!
		}
	}
	// The weighted predictor only matters when a leaf predicts with it or a
	// split tests its property (15); otherwise its state is never observed.
	mut uses_weighted := false
	for node in tree.nodes {
		if (node.is_leaf && node.predictor == .weighted) || (!node.is_leaf && node.property == 15) {
			uses_weighted = true
		}
	}
	mut symbols := SymbolReader.new(tree.histograms, mut reader, u32(image_width))!
	reference_count := if tree.num_properties > 16 {
		((tree.num_properties - 16 + 3) / 4) * 4
	} else {
		0
	}
	for c in 0 .. channels.len {
		width := channels[c].width
		height := channels[c].height
		if width == 0 || height == 0 { continue }
		if u64(width) * u64(reference_count) > 67108864 {
			return error('JPEG XL modular reference limit exceeded')
		}
		mut references := []i32{len: width * reference_count}
		mut properties := []i32{len: 256}
		properties[0] = i32(c)
		properties[1] = i32(stream_id)
		mut weighted := WeightedPredictorState.new(weighted_header, width)!
		mut current := []i32{len: width}
		mut top := []i32{len: width}
		mut toptop := []i32{len: width}
		for y in 0 .. height {
			prepare_modular_references(channels, c, y, reference_count, storage, mut references)!
			properties[9] = 0
			properties[2] = i32(y)
			for x in 0 .. width {
				data := prediction_data_in_rows(current, top, toptop, x, y)
				wp := if uses_weighted { weighted.predict_and_property(x, y, data)! } else { WeightedPrediction{} }
				mut leaf := tree.nodes[0]
				if !leaf.is_leaf {
					// Same values as compute_modular_properties; property 9 carries
					// the previous pixel's gradient into property 8.
					properties[3] = i32(x)
					properties[4] = modular_wrapping_abs(data.top)
					properties[5] = modular_wrapping_abs(data.left)
					properties[6] = data.top
					properties[7] = data.left
					properties[8] = i32(i64(data.left) - i64(properties[9]))
					properties[9] = i32(i64(data.left) + i64(data.top) - i64(data.topleft))
					properties[10] = i32(i64(data.left) - i64(data.topleft))
					properties[11] = i32(i64(data.topleft) - i64(data.top))
					properties[12] = i32(i64(data.top) - i64(data.topright))
					properties[13] = i32(i64(data.top) - i64(data.toptop))
					properties[14] = i32(i64(data.left) - i64(data.leftleft))
					properties[15] = wp.property
					for r in 0 .. reference_count { properties[16 + r] = references[x * reference_count + r] }
					mut index := u32(0)
					mut found := false
					for _ in 0 .. tree.nodes.len {
						node := tree.nodes[int(index)]
						if node.is_leaf {
							leaf = node
							found = true
							break
						}
						index = if properties[int(node.property)] > node.threshold { node.left } else { node.right }
					}
					if !found { return error('Empty or cyclic JPEG XL modular tree') }
				}
				guess := i64(u64(leaf.predictor.predict_one(data, wp.value)) + u64(i64(leaf.offset)))
				residual := symbols.read_signed(&tree.histograms, int(leaf.context), mut reader)!
				value := make_modular_pixel(residual, leaf.multiplier, guess)
				if uses_weighted { weighted.update_errors(value, x, y)! }
				current[x] = value
				channels[c].samples[y * width + x] = modular_storage_value(value, storage)
			}
			// Rotate three distinct owned buffers without allocating another row.
			unsafe {
				old := toptop
				toptop = top
				top = current
				current = old
			}
		}
	}
	symbols.check_final_state(tree.histograms, reader)!
}
