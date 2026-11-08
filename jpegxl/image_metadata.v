// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct Animation {
pub:
	ticks_numerator   u32
	ticks_denominator u32
	loops             u32
	have_timecodes    bool
}

pub struct ToneMapping {
pub:
	all_default             bool = true
	intensity_target        f32  = 255
	min_nits                f32
	relative_to_max_display bool
	linear_below            f32
}

pub struct ImageMetadata {
pub:
	orientation              Orientation = .identity
	intrinsic_size           ?Size
	preview                  ?Size
	animation                ?Animation
	bit_depth                BitDepth
	modular_16bit_sufficient bool = true
	extra_channels           []ExtraChannelInfo
	xyb_encoded              bool = true
	color_encoding           ColorEncoding
	tone_mapping             ToneMapping
}

fn (mut reader BitReader) read_animation() !Animation {
	numerator := reader.read_u32([U32Code{ offset: 100 }, U32Code{ offset: 1000 },
		U32Code{ bits: 10, offset: 1 }, U32Code{ bits: 30, offset: 1 }]!)!
	denominator := reader.read_u32([U32Code{ offset: 1 }, U32Code{ offset: 1001 },
		U32Code{ bits: 8, offset: 1 }, U32Code{ bits: 10, offset: 1 }]!)!
	loops := reader.read_u32([U32Code{}, U32Code{ bits: 3 }, U32Code{ bits: 16 }, U32Code{ bits: 32 }]!)!
	return Animation{ ticks_numerator: numerator, ticks_denominator: denominator, loops: loops, have_timecodes: reader.read(1)! != 0 }
}

fn (mut reader BitReader) read_tone_mapping() !ToneMapping {
	if reader.read(1)! != 0 { return ToneMapping{} }
	target := reader.read_f16()!
	minimum := reader.read_f16()!
	relative := reader.read(1)! != 0
	linear := reader.read_f16()!
	if target <= 0 || minimum < 0 || minimum > target || linear < 0 || (relative && linear > 1) {
		return error('Invalid JPEG XL tone mapping')
	}
	return ToneMapping{ all_default: false, intensity_target: target, min_nits: minimum, relative_to_max_display: relative, linear_below: linear }
}

pub fn (mut reader BitReader) read_image_metadata() !ImageMetadata {
	if reader.read(1)! != 0 { return ImageMetadata{} }
	extra := reader.read(1)! != 0
	mut orientation := Orientation.identity
	mut intrinsic := ?Size(none)
	mut preview := ?Size(none)
	mut animation := ?Animation(none)
	if extra {
		orientation = unsafe { Orientation(reader.read(3)! + 1) }
		if reader.read(1)! != 0 { intrinsic = reader.read_size(false)! }
		if reader.read(1)! != 0 { preview = reader.read_size(true)! }
		if reader.read(1)! != 0 { animation = reader.read_animation()! }
	}
	depth := reader.read_bit_depth()!
	sufficient := reader.read(1)! != 0
	count := int(reader.read_u32([U32Code{}, U32Code{ offset: 1 }, U32Code{ bits: 4, offset: 2 },
		U32Code{ bits: 12, offset: 1 }]!)!)
	mut channels := []ExtraChannelInfo{cap: count}
	for _ in 0 .. count { channels << reader.read_extra_channel()! }
	xyb := reader.read(1)! != 0
	color := reader.read_color_encoding()!
	tone := if extra { reader.read_tone_mapping()! } else { ToneMapping{} }
	reader.skip_extensions()!
	if count > 256 { return error('Too many JPEG XL extra channels') }
	return ImageMetadata{
		orientation:              orientation
		intrinsic_size:           intrinsic
		preview:                  preview
		animation:                animation
		bit_depth:                depth
		modular_16bit_sufficient: sufficient
		extra_channels:           channels
		xyb_encoded:              xyb
		color_encoding:           color
		tone_mapping:             tone
	}
}
