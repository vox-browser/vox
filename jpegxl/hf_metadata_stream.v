// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn checked_vardct_lf_rect(frame FrameHeader, group u64) !ImageRect {
	validate_modular_group_geometry(frame)!
	if frame.encoding != .vardct || frame.group_size_shift != 1 {
		return error('Invalid JPEG XL VarDCT LF group geometry')
	}
	return frame.lf_group_rect(group)
}

pub fn (frame FrameHeader) lf_metadata_stream_id(group u64) !u32 {
	checked_vardct_lf_rect(frame, group)!
	id := 1 + frame.num_lf_groups() * 2 + group
	if id > 4294967295 { return error('JPEG XL LF metadata stream ID overflow') }
	return u32(id)
}

// Read the HF metadata portion of an LF-group section. The caller consumes its
// VarDCT LF and modular LF streams first; section padding belongs to the owner.
pub fn (mut reader BitReader) read_hf_metadata(frame FrameHeader, group u64, depth BitDepth, storage ModularStorage, global_tree ?ModularTree) !HfMetadata {
	r := checked_vardct_lf_rect(frame, group)!
	stream_id := frame.lf_metadata_stream_id(group)!
	w := int(r.width)
	h := int(r.height)
	count := int(reader.read(ceil_log2(w * h))!) + 1
	color := ModularChannelInfo{ width: (w + 7) / 8, height: (h + 7) / 8,
		shift: ModularShift{ horizontal: 3, vertical: 3 }, bit_depth: depth }
	transforms := ModularChannelInfo{ width: count, height: 2, shift: ModularShift{}, bit_depth: depth }
	sharpness := ModularChannelInfo{ width: w, height: h, shift: ModularShift{}, bit_depth: depth }
	channels := reader.decode_modular_stream([color, color, transforms, sharpness], storage, stream_id, none, global_tree)!
	return reconstruct_hf_metadata(channels, w, h, count, frame.is444(), storage)
}
