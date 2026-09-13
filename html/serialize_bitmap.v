// Copyright (c) 2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Canvas/SerializeBitmap.{h,cpp}.
module html

import dom

pub struct SerializeBitmapResult {
pub:
	buffer    []u8
	mime_type string
}

pub type PNGEncodeCallback = fn (&dom.Bitmap_) ![]u8

pub type JPEGEncodeCallback = fn (&dom.Bitmap_, ?int) ![]u8

// https://html.spec.whatwg.org/multipage/canvas.html#a-serialisation-of-the-bitmap-as-a-file
pub fn serialize_bitmap(bitmap &dom.Bitmap_, type_ string, quality ?f64, encode_png PNGEncodeCallback, encode_jpeg JPEGEncodeCallback) !SerializeBitmapResult {
	valid_quality := if value := quality { value >= 0.0 && value <= 1.0 } else { false }
	if type_.to_lower() == 'image/jpeg' {
		jpeg_quality := if valid_quality { int(quality or { 0.0 } * 100.0) } else { none }
		return SerializeBitmapResult{
			buffer:    encode_jpeg(bitmap, jpeg_quality)!
			mime_type: 'image/jpeg'
		}
	}
	// PNG is mandatory and is the fallback for unsupported requested types.
	return SerializeBitmapResult{
		buffer:    encode_png(bitmap)!
		mime_type: 'image/png'
	}
}
