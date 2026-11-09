// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct HfNonzeroMap {
pub:
	width  int
	height int
pub mut:
	samples []u32
}

pub fn HfNonzeroMap.new(width int, height int) !HfNonzeroMap {
	if width < 0 || width > 32 || height < 0 || height > 32 {
		return error('Invalid JPEG XL HF nonzero map dimensions')
	}
	return HfNonzeroMap{ width: width, height: height, samples: []u32{len: width * height} }
}

fn (map_ HfNonzeroMap) validate() ! {
	if map_.width < 0 || map_.width > 32 || map_.height < 0 || map_.height > 32 || map_.samples.len != map_.width * map_.height {
		return error('Invalid JPEG XL HF nonzero map storage')
	}
}

pub fn (map_ HfNonzeroMap) predict_nonzeros(x int, y int) !u32 {
	map_.validate()!
	if x < 0 || x >= map_.width || y < 0 || y >= map_.height {
		return error('Invalid JPEG XL HF nonzero prediction coordinate')
	}
	if x == 0 {
		return if y == 0 { u32(32) } else { map_.samples[(y - 1) * map_.width] }
	}
	if y == 0 { return map_.samples[x - 1] }
	// Match the source u32 addition, including wrapping for public map values.
	sum := u32(map_.samples[y * map_.width + x - 1] + map_.samples[(y - 1) * map_.width + x])
	return sum / 2 + sum % 2
}

pub fn (mut map_ HfNonzeroMap) record_block(x int, y int, transform HfTransform, nonzeros u32) ! {
	map_.validate()!
	blocks := transform.covered_blocks()
	count := u32(blocks[0] * blocks[1])
	if x < 0 || y < 0 || x > map_.width - blocks[0] || y > map_.height - blocks[1]
		|| nonzeros > count * 63 {
		return error('Invalid JPEG XL HF nonzero block')
	}
	value := nonzeros / count + if nonzeros % count == 0 { u32(0) } else { u32(1) }
	for iy in 0 .. blocks[1] {
		for ix in 0 .. blocks[0] { map_.samples[(y + iy) * map_.width + x + ix] = value }
	}
}
