// Copyright (c) 2024, Lucas Chollet <lucas.chollet@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ImageBitmap.{h,cpp}.
module html

import dom

pub enum ResizeQuality {
	low
	medium
	high
	pixelated
}

pub enum ImageOrientation {
	from_image
	flip_y
}

pub enum PremultiplyAlpha {
	default_
	premultiply
	none
}

pub enum ColorSpaceConversion {
	default_
	none
}

pub struct ImageBitmapOptions {
pub:
	image_orientation      ImageOrientation     = .from_image
	premultiply_alpha      PremultiplyAlpha     = .default_
	color_space_conversion ColorSpaceConversion = .default_
	resize_width           ?u32
	resize_height          ?u32
	resize_quality         ResizeQuality = .low
}

pub enum TransferType {
	unknown
	message_port
	array_buffer
	resizable_array_buffer
	readable_stream
	writable_stream
	transform_stream
	image_bitmap
	offscreen_canvas
}

@[heap]
pub struct ImageBitmap {
mut:
	width_    u32
	height_   u32
	bitmap_   ?&dom.Bitmap_
	detached_ bool
}

pub fn ImageBitmap.create() &ImageBitmap {
	return &ImageBitmap{}
}

pub fn (bitmap &ImageBitmap) width() u32 {
	return if bitmap.detached_ { u32(0) } else { bitmap.width_ }
}

pub fn (bitmap &ImageBitmap) height() u32 {
	return if bitmap.detached_ { u32(0) } else { bitmap.height_ }
}

pub fn (bitmap &ImageBitmap) is_detached() bool {
	return bitmap.detached_
}

pub fn (mut bitmap ImageBitmap) close() {
	bitmap.detached_ = true
	bitmap.bitmap_ = none
}

pub fn (mut bitmap ImageBitmap) set_bitmap(value ?&dom.Bitmap_) {
	bitmap.bitmap_ = value
	if actual := value {
		bitmap.width_ = u32(actual.width)
		bitmap.height_ = u32(actual.height)
	} else {
		bitmap.width_ = 0
		bitmap.height_ = 0
	}
}

pub fn (bitmap &ImageBitmap) bitmap() ?&dom.Bitmap_ {
	return bitmap.bitmap_
}

fn image_bitmap_append_u32(mut output []u8, value u32) {
	output << u8(value)
	output << u8(value >> 8)
	output << u8(value >> 16)
	output << u8(value >> 24)
}

fn image_bitmap_serialize_bitmap(bitmap ?&dom.Bitmap_) []u8 {
	mut output := []u8{}
	value := bitmap or {
		image_bitmap_append_u32(mut output, 0)
		return output
	}

	image_bitmap_append_u32(mut output, u32(value.width))
	image_bitmap_append_u32(mut output, u32(value.height))
	image_bitmap_append_u32(mut output, u32(value.pitch))
	output << value.format
	output << value.alpha_type
	image_bitmap_append_u32(mut output, u32(value.data.len))
	output << value.data
	return output
}

struct ImageBitmapDecoder {
	data []u8
mut:
	offset int
}

fn (mut decoder ImageBitmapDecoder) read_u8() !u8 {
	if decoder.offset >= decoder.data.len { return error('truncated ImageBitmap data') }
	value := decoder.data[decoder.offset]
	decoder.offset++
	return value
}

fn (mut decoder ImageBitmapDecoder) read_u32() !u32 {
	if decoder.offset + 4 > decoder.data.len { return error('truncated ImageBitmap data') }
	value := u32(decoder.data[decoder.offset]) | (u32(decoder.data[decoder.offset + 1]) << 8) | (u32(decoder.data[
		decoder.offset + 2]) << 16) | (u32(decoder.data[decoder.offset + 3]) << 24)
	decoder.offset += 4
	return value
}

struct DecodedImageBitmapData {
	bitmap ?&dom.Bitmap_
}

fn (mut decoder ImageBitmapDecoder) read_bitmap() !DecodedImageBitmapData {
	width := decoder.read_u32()!
	if width == 0 { return DecodedImageBitmapData{} }
	height := decoder.read_u32()!
	pitch := decoder.read_u32()!
	format := decoder.read_u8()!
	alpha_type := decoder.read_u8()!
	length := int(decoder.read_u32()!)
	if length < 0 || decoder.offset + length > decoder.data.len {
		return error('truncated ImageBitmap pixel data')
	}
	data := decoder.data[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	return DecodedImageBitmapData{
		bitmap: &dom.Bitmap_{
			width:      int(width)
			height:     int(height)
			pitch:      int(pitch)
			format:     format
			alpha_type: alpha_type
			data:       data
		}
	}
}

pub fn (bitmap &ImageBitmap) serialization_steps() []u8 {
	return image_bitmap_serialize_bitmap(bitmap.bitmap_)
}

pub fn image_bitmap_deserialization_steps(serialized []u8) !&ImageBitmap {
	mut decoder := ImageBitmapDecoder{
		data: serialized
	}
	decoded_bitmap := decoder.read_bitmap()!
	if decoder.offset != serialized.len { return error('trailing ImageBitmap data') }
	mut image_bitmap := ImageBitmap.create()
	image_bitmap.set_bitmap(decoded_bitmap.bitmap)
	return image_bitmap
}

pub fn (mut bitmap ImageBitmap) transfer_steps() []u8 {
	serialized := image_bitmap_serialize_bitmap(bitmap.bitmap_)
	bitmap.bitmap_ = none
	bitmap.detached_ = true
	return serialized
}

pub fn image_bitmap_transfer_receiving_steps(data_holder []u8) !&ImageBitmap {
	return image_bitmap_deserialization_steps(data_holder)
}

pub fn (_ &ImageBitmap) primary_interface() TransferType {
	return .image_bitmap
}
