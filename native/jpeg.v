module main

import dom
import gg

fn C.native_decode_jpeg_yuv(bytes &u8, length uint, width &int, height &int, size &int, chroma_subsampling &int) &u8

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
		decoded := C.native_decode_jpeg_rgba(bytes.data, uint(bytes.len), &width, &height, &pitch)
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

// Chromium-policy documents hand 4:2:0 and 4:4:4 JPEG planes to the GPU as
// Chromium does, converting full-range BT.601 while sampling chroma
// bilinearly. Markers 9 (4:2:0) and 10 (4:4:4) identify the packed planes.
fn (mut app BrowserApp) chromium_jpeg_yuv_image(bytes []u8) ?gg.Image {
	$if macos {
		if !app.ctx.native_rendering || C.native_webp_yuv_paint_supported() == 0
			|| app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium {
			return none
		}
		mut width := 0
		mut height := 0
		mut size := 0
		mut chroma_subsampling := 0
		planes := C.native_decode_jpeg_yuv(bytes.data, uint(bytes.len), &width, &height, &size,
			&chroma_subsampling)
		if planes == unsafe { nil } {
			return none
		}
		mut data := []u8{len: size}
		unsafe { vmemcpy(data.data, planes, size) }
		C.native_free_jpeg_pixels(planes)
		mut image := gg.Image{
			width:       width
			height:      height
			nr_channels: if chroma_subsampling == 0 { 10 } else { 9 }
			ok:          true
			data:        data.data
		}
		image.id = app.ctx.cache_image(image)
		return image
	} $else {
		_ = bytes
		return none
	}
}
