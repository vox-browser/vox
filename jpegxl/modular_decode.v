// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Decode already transformed channels using a selected local/global tree.
// Header selection, transform scheduling and partial streaming are separate.
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
			for x in 0 .. width {
				data := PredictionData.from_rows(current, top, toptop, x, y)!
				wp := weighted.predict_and_property(x, y, data)!
				compute_modular_properties(data, x, y, references[x * reference_count..(x + 1) * reference_count], wp, mut properties)!
				prediction := tree.predict_modular(data, wp.value, properties)!
				residual := symbols.read_signed(&tree.histograms, int(prediction.context), mut reader)!
				value := make_modular_pixel(residual, prediction.multiplier, prediction.guess)
				weighted.update_errors(value, x, y)!
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
