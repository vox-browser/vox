// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub fn (frame FrameHeader) quant_table_stream_id(table_index int) !u32 {
	quant_table_blocks(table_index)!
	validate_modular_group_geometry(frame)!
	id := u64(1) + frame.num_lf_groups() * 3 + u64(table_index)
	if id > 4294967295 { return error('JPEG XL quantization stream ID overflow') }
	return u32(id)
}

// Read one quantization encoding, including mode 7's local/global modular stream.
pub fn (mut reader BitReader) read_quant_matrix(table_index int, frame FrameHeader, storage ModularStorage, global_tree ?ModularTree) !DequantMatrix {
	blocks := quant_table_blocks(table_index)!
	if reader.peek(3)! != 7 {
		return compute_quant_matrix(reader.read_nonraw_quant_encoding(table_index)!, table_index)
	}
	reader.read(3)!
	denominator := reader.read_quantization_half()!
	if denominator < f32(1e-8) { return error('Invalid JPEG XL raw quantization denominator') }
	info := ModularChannelInfo{ width: blocks[0] * 8, height: blocks[1] * 8, shift: ModularShift{}, bit_depth: BitDepth{ bits_per_sample: 8 } }
	channels := reader.decode_modular_stream([info, info, info], storage, frame.quant_table_stream_id(table_index)!, none, global_tree)!
	mut values := []i32{cap: 3 * info.width * info.height}
	for channel in channels {
		for value in channel.samples {
			if value <= 0 { return error('Invalid JPEG XL raw quantization sample') }
			values << value
		}
	}
	return raw_quant_matrix(table_index, values, denominator)
}
