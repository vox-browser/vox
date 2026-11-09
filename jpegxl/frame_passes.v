// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct Passes {
pub:
	count      u32 = 1
	shifts     []u32
	downsample []u32
	last_pass  []u32
}

pub fn (mut reader BitReader) read_passes() !Passes {
	count := reader.read_u32([U32Code{ offset: 1 }, U32Code{ offset: 2 }, U32Code{ offset: 3 },
		U32Code{ bits: 3, offset: 4 }]!)!
	if count == 1 { return Passes{} }
	stages := int(reader.read_u32([U32Code{}, U32Code{ offset: 1 }, U32Code{ offset: 2 },
		U32Code{ bits: 1, offset: 3 }]!)!)
	mut shifts := []u32{cap: int(count) - 1}
	for _ in 0 .. int(count) - 1 { shifts << u32(reader.read(2)!) }
	mut downsample := []u32{cap: stages}
	for _ in 0 .. stages { downsample << u32(1) << reader.read(2)! }
	mut last := []u32{cap: stages}
	for _ in 0 .. stages {
		last << reader.read_u32([U32Code{}, U32Code{ offset: 1 }, U32Code{ offset: 2 },
			U32Code{ bits: 3 }]!)!
	}
	return Passes{ count: count, shifts: shifts, downsample: downsample, last_pass: last }
}

pub fn (passes Passes) downsampling_bracket(pass int) !(int, int) {
	if pass < 0 || pass >= int(passes.count) || passes.downsample.len != passes.last_pass.len {
		return error('Invalid JPEG XL pass index')
	}
	mut maximum := 2
	mut minimum := 3
	for i in 0 .. pass + 1 {
		for j, last in passes.last_pass {
			if i == int(last) { minimum = ceil_log2(int(passes.downsample[j])) }
		}
		if i + 1 == int(passes.count) { minimum = 0 }
		if i != pass { maximum = if minimum > 0 { minimum - 1 } else { 0 } }
	}
	return minimum, maximum
}
