module main

import dom

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
