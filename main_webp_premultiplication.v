module main

import dom

fn C.native_decode_chromium_webp_rgba(&u8, usize, &int, &int, &int) &u8

fn chromium_tagged_webp_paint_bitmap(bytes []u8) ?&dom.Bitmap_ {
	$if macos {
		mut width := 0
		mut height := 0
		mut pitch := 0
		pixels := C.native_decode_chromium_webp_rgba(bytes.data, usize(bytes.len), &width, &height,
			&pitch)
		if pixels == unsafe { nil } { return none }
		defer { C.native_free_webp_pixels(pixels) }
		mut data := []u8{len: pitch * height}
		unsafe { vmemcpy(data.data, pixels, data.len) }
		return &dom.Bitmap_{
			width:                    width
			height:                   height
			pitch:                    pitch
			data:                     data
			native_rows_are_top_down: true
		}
	}
	return none
}

// Chromium asks libwebp for MODE_rgbA/MODE_bgrA. Those modes truncate alpha
// multiplication, unlike Skia's rounded conversion from straight RGBA.
// Preserve straight pixels in the document decoder for canvas consumers.
fn chromium_webp_paint_pixels(pixels []u8) []u8 {
	mut premultiplied := pixels.clone()
	for offset := 0; offset + 3 < pixels.len; offset += 4 {
		alpha := u32(pixels[offset + 3])
		for channel in 0 .. 3 {
			premultiplied[offset + channel] = u8(u32(pixels[offset + channel]) * alpha / 255)
		}
	}
	return premultiplied
}

fn chromium_webp_premultiplies_at_decode(bytes []u8) bool {
	// ICC-tagged images decode straight before their color transform.
	return !(bytes.len >= 21 && bytes[12..16].bytestr() == 'VP8X' && bytes[20] & 32 != 0)
}
