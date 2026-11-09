// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct WeightedPredictorHeader {
pub:
	all_default bool = true
	p1c         u32  = 16
	p2c         u32  = 10
	p3ca        u32  = 7
	p3cb        u32  = 7
	p3cc        u32  = 7
	p3cd        u32
	p3ce        u32
	w0          u32 = 13
	w1          u32 = 12
	w2          u32 = 12
	w3          u32 = 12
}

pub enum ModularTransformId {
	rct
	palette
	squeeze
	invalid
}

pub struct SqueezeParams {
pub:
	horizontal    bool
	in_place      bool
	begin_channel u32
	num_channels  u32
}

pub struct ModularTransform {
pub:
	id            ModularTransformId
	begin_channel u32
	rct_type      u32 = 6
	num_channels  u32 = 3
	num_colors    u32 = 256
	num_deltas    u32
	predictor_id  u32
	squeezes      []SqueezeParams
}

pub struct ModularGroupHeader {
pub:
	use_global_tree bool
	weighted        WeightedPredictorHeader
	transforms      []ModularTransform
}

pub fn (mut reader BitReader) read_weighted_predictor_header() !WeightedPredictorHeader {
	if reader.read(1)! != 0 { return WeightedPredictorHeader{} }
	p1c := u32(reader.read(5)!)
	p2c := u32(reader.read(5)!)
	p3ca := u32(reader.read(5)!)
	p3cb := u32(reader.read(5)!)
	p3cc := u32(reader.read(5)!)
	p3cd := u32(reader.read(5)!)
	p3ce := u32(reader.read(5)!)
	w0 := u32(reader.read(4)!)
	w1 := u32(reader.read(4)!)
	w2 := u32(reader.read(4)!)
	w3 := u32(reader.read(4)!)
	return WeightedPredictorHeader{
		all_default: false
		p1c:         p1c
		p2c:         p2c
		p3ca:        p3ca
		p3cb:        p3cb
		p3cc:        p3cc
		p3cd:        p3cd
		p3ce:        p3ce
		w0:          w0
		w1:          w1
		w2:          w2
		w3:          w3
	}
}

fn (mut reader BitReader) read_modular_begin_channel() !u32 {
	return reader.read_u32([U32Code{ bits: 3 }, U32Code{ bits: 6, offset: 8 },
		U32Code{ bits: 10, offset: 72 }, U32Code{ bits: 13, offset: 1096 }]!)
}

pub fn (mut reader BitReader) read_squeeze_params() !SqueezeParams {
	horizontal := reader.read(1)! != 0
	in_place := reader.read(1)! != 0
	begin := reader.read_modular_begin_channel()!
	count := reader.read_u32([U32Code{ offset: 1 }, U32Code{ offset: 2 }, U32Code{ offset: 3 },
		U32Code{ bits: 4, offset: 4 }]!)!
	return SqueezeParams{ horizontal: horizontal, in_place: in_place, begin_channel: begin, num_channels: count }
}

pub fn (mut reader BitReader) read_modular_transform() !ModularTransform {
	id := reader.read(2)!
	begin := if id == 0 || id == 1 { reader.read_modular_begin_channel()! } else { u32(0) }
	rct := if id == 0 {
		reader.read_u32([U32Code{ offset: 6 }, U32Code{ bits: 2 }, U32Code{ bits: 4, offset: 2 },
			U32Code{ bits: 6, offset: 10 }]!)!
	} else {
		u32(6)
	}
	channels := if id == 1 {
		reader.read_u32([U32Code{ offset: 1 }, U32Code{ offset: 3 }, U32Code{ offset: 4 },
			U32Code{ bits: 13, offset: 1 }]!)!
	} else {
		u32(3)
	}
	colors := if id == 1 {
		reader.read_u32([U32Code{ bits: 8 }, U32Code{ bits: 10, offset: 256 },
			U32Code{ bits: 12, offset: 1280 }, U32Code{ bits: 16, offset: 5376 }]!)!
	} else {
		u32(256)
	}
	deltas := if id == 1 {
		reader.read_u32([U32Code{}, U32Code{ bits: 8, offset: 1 }, U32Code{ bits: 10, offset: 257 },
			U32Code{ bits: 16, offset: 1281 }]!)!
	} else {
		u32(0)
	}
	predictor := if id == 1 { u32(reader.read(4)!) } else { u32(0) }
	mut squeezes := []SqueezeParams{}
	if id == 2 {
		count := int(reader.read_u32([U32Code{}, U32Code{ bits: 4, offset: 1 },
			U32Code{ bits: 6, offset: 9 }, U32Code{ bits: 8, offset: 41 }]!)!)
		for _ in 0 .. count { squeezes << reader.read_squeeze_params()! }
	}
	if id == 3 { return error('Invalid JPEG XL modular transform ID') }
	if rct >= 42 { return error('Invalid JPEG XL reversible color transform') }
	if predictor >= 14 { return error('Invalid JPEG XL palette predictor') }
	return ModularTransform{
		id:            unsafe { ModularTransformId(id) }
		begin_channel: begin
		rct_type:      rct
		num_channels:  channels
		num_colors:    colors
		num_deltas:    deltas
		predictor_id:  predictor
		squeezes:      squeezes
	}
}

pub fn (mut reader BitReader) read_modular_group_header() !ModularGroupHeader {
	global := reader.read(1)! != 0
	weighted := reader.read_weighted_predictor_header()!
	count := int(reader.read_u32([U32Code{}, U32Code{ offset: 1 }, U32Code{ bits: 4, offset: 2 },
		U32Code{ bits: 8, offset: 18 }]!)!)
	mut transforms := []ModularTransform{cap: count}
	for _ in 0 .. count { transforms << reader.read_modular_transform()! }
	return ModularGroupHeader{ use_global_tree: global, weighted: weighted, transforms: transforms }
}
