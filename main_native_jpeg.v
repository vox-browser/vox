module main

import dom

// Decode JPEG pixels with libjpeg-turbo's default islow IDCT and fancy chroma
// upsampling, as Chromium and upstream LibWeb do. Color-managed, CMYK and
// undecodable streams return none and keep the existing decoder.
fn native_jpeg_bitmap(bytes []u8) ?&dom.Bitmap_ {
	$if macos {
		if bytes.len < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF {
			return none
		}
		mut width := 0
		mut height := 0
		mut pitch := 0
		decoded := C.native_decode_jpeg_rgba(bytes.data, usize(bytes.len), &width, &height, &pitch)
		if decoded == unsafe { nil } {
			return none
		}
		defer {
			C.native_free_jpeg_pixels(decoded)
		}
		mut pixels := []u8{len: pitch * height}
		unsafe { vmemcpy(pixels.data, decoded, pixels.len) }
		return &dom.Bitmap_{
			width:                    width
			height:                   height
			pitch:                    pitch
			data:                     pixels
			native_rows_are_top_down: true
		}
	} $else {
		_ = bytes
		return none
	}
}
