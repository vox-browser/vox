// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub enum ExtraChannelKind {
	alpha
	depth
	spot_color
	selection_mask
	black
	cfa
	thermal
	reserved0
	reserved1
	reserved2
	reserved3
	reserved4
	reserved5
	reserved6
	reserved7
	unknown
	optional
}

pub struct ExtraChannelInfo {
pub:
	kind             ExtraChannelKind = .alpha
	bit_depth        BitDepth
	dimension_shift  u32
	name             string
	alpha_associated bool
	spot_color       ?[4]f32
	cfa_channel      ?u32
}

pub fn (mut reader BitReader) read_extra_channel() !ExtraChannelInfo {
	if reader.read(1)! != 0 { return ExtraChannelInfo{} }
	kind := reader.read_enum_value([u32(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
		16])!
	depth := reader.read_bit_depth()!
	shift := reader.read_u32([U32Code{}, U32Code{ offset: 3 }, U32Code{ offset: 4 },
		U32Code{ bits: 3, offset: 1 }]!)!
	name := reader.read_name()!
	associated := if kind == 0 { reader.read(1)! != 0 } else { false }
	mut spot := ?[4]f32(none)
	if kind == 2 {
		mut values := [4]f32{}
		for i in 0 .. 4 { values[i] = reader.read_f16()! }
		spot = values
	}
	mut cfa := ?u32(none)
	if kind == 5 {
		cfa = reader.read_u32([U32Code{ offset: 1 }, U32Code{ bits: 2 }, U32Code{ bits: 4, offset: 3 },
			U32Code{ bits: 8, offset: 19 }]!)!
	}
	if shift > 3 { return error('Invalid JPEG XL extra-channel dimension shift') }
	return ExtraChannelInfo{
		kind:             unsafe { ExtraChannelKind(kind) }
		bit_depth:        depth
		dimension_shift:  shift
		name:             name
		alpha_associated: associated
		spot_color:       spot
		cfa_channel:      cfa
	}
}
