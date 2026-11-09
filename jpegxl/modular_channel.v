// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub enum ModularStorage {
	signed16
	signed32
}

pub struct ModularShift {
pub:
	horizontal u32
	vertical   u32
}

pub struct ModularChannel {
pub:
	width  int
	height int
	shift  ?ModularShift
pub mut:
	samples []i32
}

fn modular_sample_count(width int, height int) !int {
	if width < 0 || height < 0 || width > 1048576 || height > 1048576
		|| u64(width) * u64(height) > 67108864 {
		return error('Invalid JPEG XL modular channel dimensions')
	}
	return width * height
}

pub fn ModularChannel.new(width int, height int, shift ?ModularShift) !ModularChannel {
	count := modular_sample_count(width, height)!
	return ModularChannel{ width: width, height: height, shift: shift, samples: []i32{len: count} }
}

fn (channel ModularChannel) validate() ! {
	if channel.samples.len != modular_sample_count(channel.width, channel.height)! {
		return error('Invalid JPEG XL modular channel buffer')
	}
}

fn modular_storage_value(value i32, storage ModularStorage) i32 {
	return if storage == .signed16 { i32(i16(value)) } else { value }
}

// The output is x-major, with four properties per matching previous channel.
// Reuse the same buffer for each row; missing references are explicitly zeroed.
pub fn prepare_modular_references(channels []ModularChannel, channel_index int, y int, properties_per_pixel int, storage ModularStorage, mut references []i32) ! {
	if channel_index < 0 || channel_index >= channels.len || properties_per_pixel < 0
		|| properties_per_pixel > 240 || properties_per_pixel % 4 != 0 {
		return error('Invalid JPEG XL reference property request')
	}
	target := channels[channel_index]
	target.validate()!
	if y < 0 || y >= target.height || u64(target.width) * u64(properties_per_pixel) > 67108864
		|| references.len != target.width * properties_per_pixel {
		return error('Invalid JPEG XL reference property buffer')
	}
	for i in 0 .. references.len { references[i] = 0 }
	if properties_per_pixel == 0 { return }
	mut offset := 0
	for i := channel_index - 1; i >= 0; i-- {
		if offset >= properties_per_pixel { break }
		previous := channels[i]
		if previous.width != target.width || previous.height != target.height
			|| previous.shift != target.shift {
			continue
		}
		previous.validate()!
		for x in 0 .. target.width {
			value := modular_storage_value(previous.samples[y * target.width + x], storage)
			left := if x > 0 {
				modular_storage_value(previous.samples[y * target.width + x - 1], storage)
			} else {
				i32(0)
			}
			top := if y > 0 {
				modular_storage_value(previous.samples[(y - 1) * target.width + x], storage)
			} else {
				left
			}
			topleft := if x > 0 && y > 0 {
				modular_storage_value(previous.samples[(y - 1) * target.width + x - 1], storage)
			} else {
				left
			}
			error_value := i64(value) - clamped_gradient(left, top, topleft)
			base := x * properties_per_pixel + offset
			references[base] = modular_wrapping_abs(value)
			references[base + 1] = value
			references[base + 2] = i32(if error_value < 0 { -error_value } else { error_value })
			references[base + 3] = i32(error_value)
		}
		offset += 4
	}
}
