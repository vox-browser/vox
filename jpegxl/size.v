// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct Size {
pub:
	width  u32
	height u32
}

fn ratio_width(height u32, ratio int) u64 {
	y := u64(height)
	return match ratio {
		1 { y }
		2 { y * 12 / 10 }
		3 { y * 4 / 3 }
		4 { y * 3 / 2 }
		5 { y * 16 / 9 }
		6 { y * 5 / 4 }
		7 { y * 2 }
		else { 0 }
	}
}

fn (mut b BitReader) dimension(small bool, preview bool) !u32 {
	if !preview {
		if small { return u32(b.read(5)! + 1) * 8 }
		return 1 + b.read_u32([U32Code{ bits: 9 }, U32Code{ bits: 13 }, U32Code{ bits: 18 },
			U32Code{ bits: 30 }]!)!
	}
	if small {
		return b.read_u32([U32Code{ offset: 16 }, U32Code{ offset: 32 }, U32Code{ bits: 5, offset: 1 },
			U32Code{ bits: 9, offset: 33 }]!)! * 8
	}
	return 1 + b.read_u32([U32Code{ bits: 6 }, U32Code{ bits: 8, offset: 64 },
		U32Code{ bits: 10, offset: 320 }, U32Code{ bits: 12, offset: 1344 }]!)!
}

pub fn (mut b BitReader) read_size(preview bool) !Size {
	small := b.read(1)! != 0
	height := b.dimension(small, preview)!
	ratio := int(b.read(3)!)
	width := if ratio == 0 { u64(b.dimension(small, preview)!) } else { ratio_width(height, ratio) }
	limit := if preview { u64(4096) } else { u64(1) << 30 }
	if width > limit || u64(height) > limit || width * u64(height) > u64(1) << 40 {
		return error('JPEG XL dimensions exceed format limits')
	}
	return Size{ width: u32(width), height: height }
}
