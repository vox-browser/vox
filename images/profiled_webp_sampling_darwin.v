module main

import gg
import imageraster
import layout
import painting

// Profiled VP8 uses Chromium's RGB decode path even when its color space
// canonicalizes to sRGB. Retain the full rows and generate RGB mips on the
// GPU; neither CPU byte mips nor scaled codec decode preserve those samples.
fn profiled_webp_sampling_supported(bytes []u8, image &gg.Image) bool {
	if image.path != '' || image.nr_channels != 7 || image.data == unsafe { nil }
		|| image.width <= 0 || image.height <= 0 || image.width > 4096 || image.height > 4096
		|| image.width * image.height > 4 * 1024 * 1024
		|| !imageraster.webp_srgb_profile(bytes) || imageraster.webp_lossless_srgb_profile(bytes) {
		return false
	}
	width := 1 + int(bytes[24]) + (int(bytes[25]) << 8) + (int(bytes[26]) << 16)
	height := 1 + int(bytes[27]) + (int(bytes[28]) << 8) + (int(bytes[29]) << 16)
	return image.width == width && image.height == height
}

fn (mut app BrowserApp) draw_profiled_webp(command &layout.PaintCommand, image &gg.Image,
	url string, destination painting.IntRect, source [4]f32, clip [12]f32, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| destination.width <= 0 || destination.height <= 0
		|| destination.width > 4096 || destination.height > 4096
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]! {
		return false
	}
	bytes := app.background_image_bytes(url) or { return false }
	if !profiled_webp_sampling_supported(bytes, image) { return false }
	mut clipping := clip
	clipping[0] += f32(matrix[4])
	clipping[1] += f32(matrix[5])
	return C.native_draw_sampled_png(image.data, i32(image.width), i32(image.height),
		i32(image.width), i32(image.height), 1, f32(destination.x) + f32(matrix[4]),
		f32(destination.y) + f32(matrix[5]), f32(destination.width), f32(destination.height),
		&clipping[0], page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height)) != 0
}
