// Copyright (c) 2020-2022, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2025, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ImageData.{h,cpp}.
module html

pub struct ImageDataSettings {
pub:
	color_space PredefinedColorSpace = .srgb
}

pub struct ImageDataBitmap {
pub:
	width  u32
	height u32
	data   []u8
}

@[heap]
pub struct ImageData {
mut:
	bitmap_      ImageDataBitmap
	color_space_ PredefinedColorSpace = .srgb
	data_        []u8
}

pub fn ImageData.create(sw u32, sh u32, settings ?ImageDataSettings) !&ImageData {
	if sw == 0 || sh == 0 {
		return error('IndexSizeError: source width and height must be greater than zero')
	}
	byte_length := u64(sw) * u64(sh) * 4
	if byte_length > u64(max_int) {
		return error('IndexSizeError: specified image size could not be created')
	}
	data := []u8{len: int(byte_length)}
	return image_data_initialize(sh, sw, settings, data, none)
}

pub fn ImageData.create_with_data(data []u8, sw u32, sh ?u32, settings ?ImageDataSettings) !&ImageData {
	if data.len == 0 || data.len % 4 != 0 {
		return error('InvalidStateError: source data length must be a nonzero multiple of four')
	}
	pixel_count := u32(data.len / 4)
	if sw == 0 || pixel_count % sw != 0 {
		return error("IndexSizeError: source width must divide the source data's pixel length")
	}
	height := pixel_count / sw
	if supplied_height := sh {
		if supplied_height != height {
			return error('IndexSizeError: source height must equal the calculated height')
		}
	}
	return image_data_initialize(height, sw, settings, data, none)
}

fn image_data_initialize(rows u32, pixels_per_row u32, settings ?ImageDataSettings, source []u8, default_color_space ?PredefinedColorSpace) &ImageData {
	color_space := if actual_settings := settings {
		actual_settings.color_space
	} else if default_space := default_color_space {
		default_space
	} else {
		PredefinedColorSpace.srgb
	}
	return &ImageData{
		bitmap_:      ImageDataBitmap{
			width:  pixels_per_row
			height: rows
			data:   source
		}
		color_space_: color_space
		data_:        source
	}
}

pub fn (data &ImageData) width() u32 {
	return data.bitmap_.width
}

pub fn (data &ImageData) height() u32 {
	return data.bitmap_.height
}

pub fn (data &ImageData) bitmap() ImageDataBitmap {
	return data.bitmap_
}

// V slices are shared views, matching Uint8ClampedArray's mutable backing
// storage. Values assigned to an element are naturally clamped to u8.
pub fn (data &ImageData) data() []u8 {
	return data.data_
}

pub fn (data &ImageData) color_space() PredefinedColorSpace {
	return data.color_space_
}

fn image_data_append_u32(mut output []u8, value u32) {
	output << u8(value)
	output << u8(value >> 8)
	output << u8(value >> 16)
	output << u8(value >> 24)
}

pub fn (data &ImageData) serialization_steps() []u8 {
	mut output := []u8{}
	// [[Data]], [[Width]], [[Height]], [[ColorSpace]].
	image_data_append_u32(mut output, u32(data.data_.len))
	output << data.data_
	image_data_append_u32(mut output, data.width())
	image_data_append_u32(mut output, data.height())
	output << u8(data.color_space_)
	return output
}

struct ImageDataDecoder {
	data []u8
mut:
	offset int
}

fn (mut decoder ImageDataDecoder) read_u8() !u8 {
	if decoder.offset >= decoder.data.len {
		return error('truncated ImageData serialization')
	}
	value := decoder.data[decoder.offset]
	decoder.offset++
	return value
}

fn (mut decoder ImageDataDecoder) read_u32() !u32 {
	if decoder.offset + 4 > decoder.data.len {
		return error('truncated ImageData serialization')
	}
	value := u32(decoder.data[decoder.offset]) | (u32(decoder.data[decoder.offset + 1]) << 8) | (u32(decoder.data[
		decoder.offset + 2]) << 16) | (u32(decoder.data[decoder.offset + 3]) << 24)
	decoder.offset += 4
	return value
}

pub fn image_data_deserialization_steps(serialized []u8) !&ImageData {
	mut decoder := ImageDataDecoder{
		data: serialized
	}
	length := int(decoder.read_u32()!)
	if length < 0 || decoder.offset + length > serialized.len {
		return error('truncated ImageData pixel data')
	}
	pixels := serialized[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	width := decoder.read_u32()!
	height := decoder.read_u32()!
	color_space := match decoder.read_u8()! {
		0 { PredefinedColorSpace.srgb }
		1 { PredefinedColorSpace.display_p3 }
		else { return error('invalid ImageData color space') }
	}
	if decoder.offset != serialized.len {
		return error('trailing ImageData serialization data')
	}
	if u64(width) * u64(height) * 4 != u64(pixels.len) {
		return error('ImageData dimensions do not match pixel data')
	}
	return image_data_initialize(height, width, none, pixels, color_space)
}
