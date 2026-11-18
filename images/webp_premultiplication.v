module main

import cpuraster
import imageraster

// Chromium asks libwebp for MODE_rgbA/MODE_bgrA. Those modes truncate alpha
// multiplication, unlike Skia's rounded conversion from straight RGBA.
// Preserve straight pixels in the document decoder for canvas consumers.
fn chromium_webp_paint_pixels(pixels []u8) []u8 {
	return cpuraster.premultiply_rgba_copy_truncated(pixels)
}

fn chromium_webp_premultiplies_at_decode(bytes []u8) bool {
	// Canonical sRGB profiles need no transform; other ICC-tagged images
	// decode straight before their existing color-managed conversion.
	return !(bytes.len >= 21 && bytes[12..16].bytestr() == 'VP8X' && bytes[20] & 32 != 0)
		|| imageraster.webp_srgb_profile(bytes)
}
